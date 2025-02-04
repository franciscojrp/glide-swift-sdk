import Foundation

class GlideRepository: Repository {
    let threeLeggedAuthFlow: ThreeLeggedAuthFlow
    
    init(threeLeggedAuthFlow: ThreeLeggedAuthFlow) {
        self.threeLeggedAuthFlow = threeLeggedAuthFlow
    }
    
    func threeLeggedAuthenticate(config: ThreeLeggedConfig) async throws -> (code: String, state: String) {
        let response = try await threeLeggedAuthFlow.authenticate(config: config)
        return (code: response.code, state: response.state)
    }
}
