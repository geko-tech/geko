import Foundation

/// Stable top-level keys for scalar values and command-specific results.
public enum CommandOutputKey: String {
    case graph
    case targetOwnership
    case workspacePath
    case xcconfigPath
    case clean
    case dump
    case pluginArchive
    case pluginExecutablePath
    case gekoVersion
    case projectDescriptionVersion
    case tree
    case cacheUpload
    case bump
    case inspectImports
    case migrationTargets
    case output
}

/// Namespaces that several stages of one command may populate incrementally.
public enum CommandOutputSection: String {
    case focus
    case cache
}

/// Associates a field with exactly one structured-output section.
public protocol CommandOutputSectionKey: RawRepresentable where RawValue == String {
    static var section: CommandOutputSection { get }
}

public enum FocusOutputKey: String, CommandOutputSectionKey {
    case requestedTargets
    case focusedTargets
    case scheme
    case focusTests

    public static let section = CommandOutputSection.focus
}

public enum CacheOutputKey: String, CommandOutputSectionKey {
    case profile
    case configuration
    case destination
    case platforms

    case swiftModuleCacheEnabled
    case onlyActiveResourcesInBundles
    case exportCoverageProfiles

    case ignoreRemoteCache
    case focusDirectDependencies
    case dependenciesOnly
    case unsafe

    public static let section = CommandOutputSection.cache
}
