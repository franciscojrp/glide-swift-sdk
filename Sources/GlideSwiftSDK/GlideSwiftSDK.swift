import Foundation

public final class Glide {
    
    @MainActor public static let instance = Glide(repository: GlideRepository(threeLeggedAuthFlow: ThreeLeggedAuthFlow()))
    
    private let repository : Repository
    private var clientId: String!
    private var authBaseUrl: String!
    private var redirectUri: String?
    
    @MainActor public static func configure(clientId: String, authBaseUrl: String, redirectUri: String? = nil) {
        Glide.instance.clientId = clientId
        Glide.instance.redirectUri = redirectUri
        Glide.instance.authBaseUrl = authBaseUrl
    }
    
    init(repository : Repository) {
        self.repository = repository
    }
    
    public func startVerification(state: String, printCode: Bool = false, phoneNumber: String? = nil) async throws -> (code: String, state: String) {
        let config = ThreeLeggedConfig(
            state: state,
            printCode: printCode,
            authBaseUrl: self.authBaseUrl,
            clientID: self.clientId,
            phoneNumber: phoneNumber,
            redirectUri: self.redirectUri
        )
        return try await self.repository.threeLeggedAuthenticate(config: config)
    }
}
