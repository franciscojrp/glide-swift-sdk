import Foundation

protocol Repository {
    func threeLeggedAuthenticate(config: ThreeLeggedConfig) async throws -> (code: String, state: String) 
}
