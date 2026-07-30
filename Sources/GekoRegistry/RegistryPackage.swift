import Foundation
import GekoSupport
import GekoCocoapods
import ProjectDescription

public typealias RegistryPackageVersion = ProjectDescription.PackageVersion

public struct RegistryPackage: Codable {
    public let name: String
    public let version: PackageVersion
    public let dependencies: [PackageDependency]

    public let artifact: Artifact

    public let modules: [Module]

    public init(
        name: String,
        version: PackageVersion,
        dependencies: [PackageDependency],
        artifact: Artifact = .init(path: nil),
        modules: [Module] = []
    ) {
        self.name = name
        self.version = version
        self.dependencies = dependencies

        self.artifact = artifact

        self.modules = modules
    }
}

// MARK: - Modules

extension RegistryPackage {
    public struct Module: Codable {
        public let name: String
        public let product: String
        public let flavors: [String: Flavor]

        public init(
            name: String,
            product: String,
            flavors: [String: Flavor]
        ) {
            self.name = name
            self.product = product
            self.flavors = flavors
        }
    }

    public struct Flavor: Codable {
        public let sources: [SourceFiles]

        public init(sources: [SourceFiles]) {
            self.sources = sources
        }
    }
}

// MARK: - Resolver stuff

extension RegistryPackage {
    public typealias Version = ProjectDescription.PackageVersion

    public struct PackageDependency: Codable {
        public let name: String
        public let requirement: CocoapodsVersionRange

        public init(
            name: String,
            requirement: CocoapodsVersionRange
        ) {
            self.name = name
            self.requirement = requirement
        }
    }

    public struct PackageRequirement: Codable {
        public let fromVersion: Version?
        public let fromLimit: PackageRequirementLimit
        public let upToVersion: Version?
        public let upToLimit: PackageRequirementLimit

        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()

            let str = try c.decode(String.self)

            self.fromVersion = nil
            self.fromLimit = .unbounded
            self.upToVersion = nil
            self.upToLimit = .unbounded
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()

            try c.encode("")
        }

    }

    public enum PackageRequirementLimit {
        case included
        case excluded
        case unbounded
    }
}

// MARK: - Artifact

extension RegistryPackage {
    public struct Artifact: Codable {
        public var path: String?

        public init(path: String? = nil) {
            self.path = path
        }
    }
}

// MARK: - Utils

func componentsFrom(string: String) -> (
    Version?, RegistryPackage.PackageRequirementLimit,
    Version?, RegistryPackage.PackageRequirementLimit
) {
    return (nil, .unbounded, nil, .unbounded)
}

func componentsToString(
    from: Version?, fromLimit: RegistryPackage.PackageRequirementLimit,
    to: Version?, toLimit: RegistryPackage.PackageRequirementLimit
) -> String {
    return ""
}

private func splitComponents(from string: String) -> [String] {
    return []
}
