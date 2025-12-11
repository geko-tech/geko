import ProjectDescription

// MARK: - Target

public struct TargetFlags: OptionSet, Codable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public static let sharedTestTarget = TargetFlags(rawValue: 1 << 32)
    public static let sharedTestTargetAppHost = TargetFlags(rawValue: 1 << 33)
    public static let sharedTestTargetGeneratedFramework = TargetFlags(rawValue: 1 << 34)
}

/// Side table to store additional information about target that does not need to be exposed to user
public struct TargetSideTable {
    public var flags: TargetFlags
    
    // TODO A temporary workaround
    public var sources: [SourceFiles]
    public var resources: [RelativePath]
    public var additionalFiles: [FilePath]

    public init(
        flags: TargetFlags = [],
        sources: [SourceFiles] = [],
        resources: [RelativePath] = [],
        additionalFiles: [FilePath] = []
    ) {
        self.flags = flags
        self.sources = sources
        self.resources = resources
        self.additionalFiles = additionalFiles
    }
}

// MARK: - Project

public struct ProjectSideTable {
    public var targets: [String: TargetSideTable]

    public init() {
        targets = [:]
    }

    public mutating func setTargetFlags(_ flags: TargetFlags, name: String) {
        self.targets[name, default: .init()].flags = flags
    }

    public func targetFlags(name: String) -> TargetFlags {
        return self.targets[name]?.flags ?? []
    }
}

// MARK: - Workspace

public struct WorkspaceSideTable {
    public var projects: [AbsolutePath: ProjectSideTable]
    public var focusedTargets: Set<String>
    public var dependenciesGraph: DependenciesGraph

    public init() {
        projects = [:]
        focusedTargets = []
        dependenciesGraph = .none
    }

    public mutating func setTargetFlags(_ flags: TargetFlags, path: AbsolutePath, name: String) {
        self.projects[path, default: .init()]
            .targets[name, default: .init()].flags = flags
    }

    public func targetFlags(path: AbsolutePath, name: String) -> TargetFlags {
        return self.projects[path]?.targets[name]?.flags ?? []
    }
}

// MARK: - Graph

public struct GraphSideTable {
    public var workspace: WorkspaceSideTable

    public init() {
        workspace = .init()
    }

    public mutating func setTargetFlags(_ flags: TargetFlags, path: AbsolutePath, name: String) {
        self.workspace
            .projects[path, default: .init()]
            .targets[name, default: .init()].flags = flags
    }

    public func targetFlags(path: AbsolutePath, name: String) -> TargetFlags {
        return self.workspace.projects[path]?.targets[name]?.flags ?? []
    }
    
    public mutating func setSources(_ sources: [SourceFiles], path: AbsolutePath, name: String) {
        self.workspace
            .projects[path, default: .init()]
            .targets[name, default: .init()].sources = sources
    }
    
    public func sources(path: AbsolutePath, name: String) -> [SourceFiles] {
        return self.workspace.projects[path]?.targets[name]?.sources ?? []
    }
    
    public mutating func setResources(_ resources: [FilePath], path: AbsolutePath, name: String) {
        self.workspace
            .projects[path, default: .init()]
            .targets[name, default: .init()].resources = resources
    }
    
    public func resources(path: AbsolutePath, name: String) -> [FilePath] {
        return self.workspace.projects[path]?.targets[name]?.resources ?? []
    }
    
    public mutating func setAdditionalFiles(_ additionalFiles: [FilePath], path: AbsolutePath, name: String) {
        self.workspace
            .projects[path, default: .init()]
            .targets[name, default: .init()].additionalFiles = additionalFiles
    }
    
    public func additionalFiles(path: AbsolutePath, name: String) -> [FilePath] {
        return self.workspace.projects[path]?.targets[name]?.additionalFiles ?? []
    }
}
