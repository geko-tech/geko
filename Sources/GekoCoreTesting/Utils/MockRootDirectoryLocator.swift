import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoCore

public final class MockRootDirectoryLocator: RootDirectoryLocating {
    public var locateArgs: [AbsolutePath] = []
    public var locateStub: AbsolutePath?
    
    public init() {}

    public func locate(from path: AbsolutePath) -> AbsolutePath? {
        locateArgs.append(path)
        return locateStub
    }
}
