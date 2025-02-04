

enum SDKError: Error {
    case statusCode(Int, String)
    case unknown(Error)
    case invalidConfiguration
    
    var localizedDescription: String {
        switch self {
        case .statusCode(let code, let desctiption):
            return "Request failed with status code: \(code) -- Description: \(desctiption)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        case .invalidConfiguration:
            return "The SDK is not configured correctly"
        }
    }
}

struct APIError: Codable {
    let error: String
    let error_description: String
}
