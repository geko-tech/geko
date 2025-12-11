/// The Package.resolved information.
/// It decodes data encoded from Package.resolved
/// https://github.com/swiftlang/swift-package-manager/blob/ce50cb0de101c2d9a5742aaf70efc7c21e8f249b/Sources/PackageModel/PackageReference.swift
/// In particular, we are interested in the CheckoutState.swift:
/// https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Workspace/CheckoutState.swift
/// and ResolvedPackagesStore.swift:
/// https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageGraph/ResolvedPackagesStore.swift
struct SwiftPackageManagerResolvedState: Codable, Equatable {
    let pins: [DependencyInfo]
    
    struct DependencyInfo: Codable, Equatable {
        let identity: String
        let kind: String
        let location: String
        let state: CheckoutState
    }
    
    /// A checkout state represents the current state of a repository.
    ///
    /// A state will always have a revision. It can also have a branch or a version but not both.
    struct CheckoutState: Codable, Equatable {
        let revision: String
        let version: String?
        let branch: String?
    }
}
