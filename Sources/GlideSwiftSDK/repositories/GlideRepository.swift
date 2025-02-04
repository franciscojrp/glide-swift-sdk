import Foundation

class GlideRepository: Repository {
    let threeLeggedAuthFlow: ThreeLeggedAuthFlow
    
    init(threeLeggedAuthFlow: ThreeLeggedAuthFlow) {
        self.threeLeggedAuthFlow = threeLeggedAuthFlow
    }
    
    func threeLeggedAuthenticate(config: ThreeLeggedConfig) async throws -> (code: String, state: String) {
        let response = try await threeLeggedAuthFlow.authenticate(config: config)
        logger.info("\(threeLeggedFlowName) success with status: \(response)")
        return (code: response.code, state: response.state)
    }
}
