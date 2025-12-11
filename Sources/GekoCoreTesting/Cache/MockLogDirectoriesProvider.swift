import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
@testable import GekoCore

public final class MockLogDirectoriesProvider: LogDirectoriesProviding {
    private let directory: TemporaryDirectory
    public var logDirectoryStub: AbsolutePath?
    
    private var logDirectory: AbsolutePath {
        logDirectoryStub ?? directory.path
    }
    
    public init() throws {
        directory = try TemporaryDirectory(removeTreeOnDeinit: true)
    }
    
    public func logDirectory(for category: GekoCore.LogCategory) throws -> ProjectDescription.AbsolutePath {
        logDirectory.appending(component: category.directoryName)
    }
}
