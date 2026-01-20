import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public final class StubCocoapodsLocationProvider: CocoapodsLocationProviding {

    public init() {}

    public var shellCommandStub: ((Config) throws -> [String])?

    public func shellCommand(config: Config) throws -> [String] {
        try shellCommandStub?(config) ?? []
    }
}
