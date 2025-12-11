import Foundation
import GekoCore
import GekoGraph

public final class StubCocoapodsLocationProvider: CocoapodsLocationProviding {

    public init() {}

    public var shellCommandStub: ((GekoGraph.Config) throws -> [String])?

    public func shellCommand(config: GekoGraph.Config) throws -> [String] {
        try shellCommandStub?(config) ?? []
    }
}
