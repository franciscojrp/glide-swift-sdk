import Foundation
import Network

final class CellularDataProvider: Sendable {
    func request(request: URLRequest) async throws -> (data: Data, response: URLResponse) {
        try await performRequest(request: request)
    }
    
    private func performRequest(request: URLRequest) async throws -> (data: Data, response: URLResponse) {
        guard let url = request.url, let host = url.host else {
            throw URLError(.badURL)
        }
        
        let connection = createConnection(for: url)
        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    self?.sendRequest(connection, with: request, host: host, continuation: continuation)
                case .failed(let error):
                    print("####### Connection failed: \(error)")
                    continuation.resume(throwing: error)
                case .waiting(let error):
                    print("####### Connection waiting: \(error)")
                    connection.cancel()
                case .cancelled:
                    print("####### Connection cancelled")
                    continuation.resume(throwing: SDKError.mobileNetworkConnectionCannotBeEstablished)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
    
    private func receiveResponse(_ connection: NWConnection,
                                 originalRequest: URLRequest,
                                 continuation: CheckedContinuation<(Data, URLResponse), Error>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            do {
                if let error = error {
                    throw error
                }
                
                guard let data = data,
                      let (body, response) = self?.parseResponse(data),
                      let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                // Handle network drops during response
                if httpResponse.statusCode == 408 || httpResponse.statusCode == 504 {
                    throw URLError(.timedOut)
                }
                
                if (300...399).contains(httpResponse.statusCode),
                   let location = httpResponse.allHeaderFields["Location"] as? String {
                    guard let redirectURL = URL(string: location, relativeTo: originalRequest.url) else {
                        throw URLError(.badURL)
                    }
                    
                    var redirectRequest = originalRequest
                    redirectRequest.url = redirectURL
                    Task {
                        do {
                            let result = try await self?.performRequest(request: redirectRequest)
                            if let result = result {
                                continuation.resume(returning: result)
                            }
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    continuation.resume(returning: (body, response))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func createConnection(for url: URL) -> NWConnection {
        let endpoint = NWEndpoint.url(url)
        let parameters = NWParameters.tls
        parameters.requiredInterfaceType = .cellular
        return NWConnection(to: endpoint, using: parameters)
    }
    
    private func sendRequest(_ connection: NWConnection,
                             with request: URLRequest,
                             host: String,
                             continuation: CheckedContinuation<(data: Data, response: URLResponse), Error>) {
        let requestData = createRequestData(from: request, host: host)
        connection.send(content: requestData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                self?.receiveResponse(connection, originalRequest: request, continuation: continuation)
            }
        })
    }
    
    private func receiveResponse(_ connection: NWConnection,
                                 originalRequest: URLRequest,
                                 continuation: CheckedContinuation<(data: Data, response: URLResponse), Error>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self else {
                continuation.resume(throwing: URLError(.unknown))
                return
            }
            
            do {
                if let error = error {
                    throw error
                }
                
                guard let data = data,
                      let (body, response) = self.parseResponse(data),
                      let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if (300...399).contains(httpResponse.statusCode),
                   let location = httpResponse.allHeaderFields["Location"] as? String,
                   let redirectURL = URL(string: location, relativeTo: originalRequest.url) {
                    var redirectRequest = originalRequest
                    redirectRequest.url = redirectURL
                    Task {
                        do {
                            let result = try await self.performRequest(request: redirectRequest)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    continuation.resume(returning: (body, response))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func createRequestData(from request: URLRequest, host: String) -> Data {
        // Use the full URL with query parameters if present
        let fullPath = request.url?.path ?? "/"
        let queryString = request.url?.query.map { "?\($0)" } ?? ""
        
        var httpRequestData = "\(request.httpMethod ?? "GET") \(fullPath)\(queryString) HTTP/1.1\r\n"
        httpRequestData += "Host: \(host)\r\n"
        
        if let headers = request.allHTTPHeaderFields {
            for (headerField, value) in headers {
                httpRequestData += "\(headerField): \(value)\r\n"
            }
        }
        httpRequestData += "\r\n"
        
        var requestData = httpRequestData.data(using: .utf8)!
        
        // If there is a body, append it to the request data
        if let body = request.httpBody {
            requestData.append(body)
        }
        
        return requestData
    }
    
    private func parseResponse(_ data: Data) -> (Data, URLResponse)? {
        guard let responseString = String(data: data, encoding: .utf8),
              let headerEndRange = responseString.range(of: "\r\n\r\n") else {
            return nil
        }
        
        let headerPart = responseString[..<headerEndRange.lowerBound]
        let bodyPart = data.subdata(in: headerEndRange.upperBound.utf16Offset(in: responseString)..<data.count)
        let headerLines = headerPart.split(separator: "\r\n")
        let statusLine = headerLines.first ?? ""
        let statusComponents = statusLine.split(separator: " ")
        
        guard statusComponents.count >= 3,
              let statusCode = Int(statusComponents[1]),
              let url = URL(string: String(statusComponents[0])) else {
            return nil
        }
        
        var headerFields = [String: String]()
        for line in headerLines.dropFirst() {
            let parts = line.components(separatedBy: ": ")
            if parts.count == 2 {
                headerFields[parts[0]] = parts[1]
            }
        }
        
        if let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headerFields) {
            return (bodyPart, response)
        }
        
        return nil
    }
}
