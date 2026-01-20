import Foundation
import GekoGraph
import GekoLoader
import ProjectDescription

public final class MockConfigLoader: ConfigLoading {
    public init() {}

    public var loadConfigStub: ((AbsolutePath) throws -> Config)?
    public func loadConfig(path: AbsolutePath) throws -> Config {
        try loadConfigStub?(path) ?? .default
    }

    public var locateConfigStub: ((AbsolutePath) -> AbsolutePath?)?
    public func locateConfig(at: AbsolutePath) -> AbsolutePath? {
        locateConfigStub?(at)
    }
}
