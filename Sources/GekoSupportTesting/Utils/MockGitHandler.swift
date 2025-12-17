import ProjectDescription
import GekoSupport

/// A mock implementation of `GitHandling`.
public final class MockGitHandler: GitHandling {
    
    public init() {}

    public var cloneIntoStub: ((String, AbsolutePath) -> Void)?
    public func clone(url: String, into path: AbsolutePath) throws {
        cloneIntoStub?(url, path)
    }

    public var cloneToStub: ((String, AbsolutePath?) -> Void)?
    public func clone(url: String, to path: AbsolutePath?) throws {
        cloneToStub?(url, path)
    }

    public var cloneToShallowBranchStub: ((String, AbsolutePath, Bool, String?) -> Void)?
    public func clone(url: String, to path: ProjectDescription.AbsolutePath, shallow: Bool, branch: String?) throws {
        cloneToShallowBranchStub?(url, path, shallow, branch)
    }

    public var updateSubmodulesStub: ((AbsolutePath) -> Void)?
    public func updateSubmodules(path: ProjectDescription.AbsolutePath) throws {
        updateSubmodulesStub?(path)
    }

    public var checkoutStub: ((String, AbsolutePath?) -> Void)?
    public func checkout(id: String, in path: AbsolutePath?) throws {
        checkoutStub?(id, path)
    }

    public var remoteTaggedVersionsStub: [String]?
    public func remoteTaggedVersions(url _: String) -> [Version] {
        remoteTaggedVersionsStub?.compactMap { Version($0) } ?? []
    }

    public var pullStub: ((AbsolutePath?) -> Void)?
    public func pull(in path: ProjectDescription.AbsolutePath?) throws {
        pullStub?(path)
    }
}
