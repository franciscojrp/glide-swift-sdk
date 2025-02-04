import Foundation

let threeLeggedFlowName = "three_legged_flow"

class ThreeLeggedAuthFlow {
    private let cellularDataProvider = CellularDataProvider()
    
    func authenticate(config: ThreeLeggedConfig) async throws -> ThreeLeggedResponse {
        return try await auth(config: config)
    }
    
    private func auth(config: ThreeLeggedConfig) async throws -> ThreeLeggedResponse {
        let request = try createRequest(config: config)
        let (data, response) = try await cellularDataProvider.request(request: request)
        let validData = try validateResponse(data: data, response: response)
        return try JSONDecoder().decode(ThreeLeggedResponse.self, from: validData)
    }
    
    private func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == successCode else {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            throw SDKError.statusCode(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                error?.error_description ?? ""
            )
        }
        return data
    }
    
    private func createRequest(config: ThreeLeggedConfig) throws -> URLRequest {
        guard let url = generateAuthUrl(config: config) else {
            logger.error("\(threeLeggedFlowName): invalid config")
            throw SDKError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
    
    private func generateAuthUrl(config: ThreeLeggedConfig) -> URL? {
        var components = URLComponents(string: "\(config.authBaseUrl)/oauth2/auth?")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri ?? ""),
            URLQueryItem(name: "scope", value: "openid"),
            URLQueryItem(name: "purpose", value: "dpv:FraudPreventionAndDetection:number-verification"),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "dev_print", value: "true"),
            URLQueryItem(name: "max_age", value: "0")
        ]
        
        if let phoneNumber = config.phoneNumber {
            components?.queryItems?.append(URLQueryItem(
                name: "login_hint",
                value: "tel:\(phoneNumber)"
            ))
        }
        
        return components?.url
    }
}

struct ThreeLeggedConfig {
    let state: String
    let printCode: Bool
    let authBaseUrl: String
    let clientID: String
    let phoneNumber: String?
    let redirectUri: String?
}

struct ThreeLeggedResponse: Codable {
    let code: String
    let state: String
}
