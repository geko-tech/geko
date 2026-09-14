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
    case initProject
    case scaffold
    case scaffoldList
    case xcodebuild
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

/// Associates an accumulating collection with one top-level output key.
public protocol CommandOutputCollectionKey: RawRepresentable where RawValue == String {
    static var outputKey: CommandOutputKey { get }
}

public enum XcodeBuildOutputKey: String, CommandOutputCollectionKey {
    case invocations

    public static let outputKey = CommandOutputKey.xcodebuild
}

public enum FocusOutputKey: String, CommandOutputSectionKey {
    case requestedTargets
    case focusedTargets
    case scheme
    case focusTests
    case handoff

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
