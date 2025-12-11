import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoScaffold

public final class MockTemplatesDirectoryLocator: TemplatesDirectoryLocating {
    public init() {}

    public var locateUserTemplatesStub: ((AbsolutePath) -> AbsolutePath?)?
    public var locateGekoTemplatesStub: (() -> AbsolutePath?)?
    public var templateDirectoriesStub: ((AbsolutePath) throws -> [AbsolutePath])?
    public var templatePluginDirectoriesStub: ((AbsolutePath) throws -> [AbsolutePath])?

    public func locateUserTemplates(at: AbsolutePath) -> AbsolutePath? {
        locateUserTemplatesStub?(at)
    }

    public func locateGekoTemplates() -> AbsolutePath? {
        locateGekoTemplatesStub?()
    }

    public func templateDirectories(at path: AbsolutePath) throws -> [AbsolutePath] {
        try templateDirectoriesStub?(path) ?? []
    }

    public func templatePluginDirectories(at path: AbsolutePath) throws -> [AbsolutePath] {
        try templatePluginDirectoriesStub?(path) ?? []
    }
}
