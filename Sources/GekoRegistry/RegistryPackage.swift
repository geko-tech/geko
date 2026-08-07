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

    public let flavors: [String]?
    public let modules: [Module]

    public init(
        name: String,
        version: PackageVersion,
        dependencies: [PackageDependency],
        artifact: Artifact = .init(path: nil),
        flavors: [String]? = nil,
        modules: [Module] = []
    ) {
        self.name = name
        self.version = version
        self.dependencies = dependencies

        self.artifact = artifact

        self.flavors = flavors
        self.modules = modules
    }
}

// MARK: - Modules

extension RegistryPackage {
    public struct Module: Codable {
        public let name: String
        public let product: String

        public let flavor: String?

        public let dependencies: [ModuleDependency]?

        public let sources: [SourceFiles]?
        public let resources: [ResourceFileElement]?
        public let settings: Settings?

        public init(
            name: String,
            product: String,
            flavor: String? = nil,
            dependencies: [ModuleDependency]? = nil,
            sources: [SourceFiles]? = nil,
            resources: [ResourceFileElement]? = nil,
            settings: Settings?
        ) {
            self.name = name
            self.product = product

            self.flavor = flavor

            self.dependencies = dependencies

            self.sources = sources
            self.resources = resources
            self.settings = settings
        }
    }

    public enum ModuleDependencyType: String, Codable {
        // external package
        case external
        // dependency within package
        case local
    }

    public struct ModuleDependency: Codable {
        public let name: String
        public let type: ModuleDependencyType

        public init(
            name: String,
            type: ModuleDependencyType
        ) {
            self.name = name
            self.type = type
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
