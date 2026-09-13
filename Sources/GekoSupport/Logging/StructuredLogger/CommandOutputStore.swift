import Foundation
import AnyCodable

public protocol CommandOutputStoring {
    func appendWarning(_ message: String)

    func appendError(_ message: String)
    
    func set<T: Encodable> (_ key: CommandOutputKey, value: T)
    
    func set<Key, Value>(_ key: Key, value: Value, in section: CommandOutputKey) where Key: RawRepresentable, Key.RawValue == String, Value: Encodable

    func drainWarnings() -> [CommandDiagnostic]

    func drainErrors() -> [CommandDiagnostic]
    
    func drainData() -> [String: AnyCodable]
}

public enum CommandOutputKey: String {
    case graph
    case targetOwnership
    case focus
    case cache
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
}

public enum FocusOutputKey: String {
    case requestedTargets
    case focusedTargets
    case scheme
    case focusTests
}

public enum CacheOutputKey: String {
    case profile
    case configuration
    case destination
    case platforms
    
    case cacheEnabled
    case swiftModuleCacheEnabled
    case onlyActiveResourcesInBundles
    case exportCoverageProfiles
    
    case ignoreRemoteCache
    case focusDirectDependencies
    case dependenciesOnly
    case unsafe
}

public final class CommandOutputStore: CommandOutputStoring {
    public static let shared: CommandOutputStoring = CommandOutputStore()
    
    private let lock = NSLock()
    
    private var warnings: [CommandDiagnostic] = []
    private var errors: [CommandDiagnostic] = []
    private var data: [String: AnyCodable] = [:]
    
    // MARK: - CommandOutputStoring
    
    public func appendWarning(_ message: String) {
        lock.withLock {
            warnings.append(CommandDiagnostic(message: message))
        }
    }

    public func appendError(_ message: String) {
        lock.withLock {
            errors.append(CommandDiagnostic(message: message))
        }
    }
    
    public func set<T: Encodable> (
        _ key: CommandOutputKey,
        value: T
    ) {
        lock.withLock {
            data[key.rawValue] = AnyCodable(value)
        }
    }
    
    public func set<Key, Value>(
        _ key: Key,
        value: Value,
        in section: CommandOutputKey
    ) where Key: RawRepresentable, Key.RawValue == String, Value: Encodable {
        lock.withLock {
            var sectionData = data[section.rawValue]?.value as? [String: AnyCodable] ?? [:]
            sectionData[key.rawValue] = AnyCodable(value)
            data[section.rawValue] = AnyCodable(sectionData)
        }
    }

    public func drainWarnings() -> [CommandDiagnostic] {
        lock.withLock {
            defer { warnings.removeAll() }
            return warnings
        }
    }

    public func drainErrors() -> [CommandDiagnostic] {
        lock.withLock {
            defer { errors.removeAll() }
            return errors
        }
    }
    
    public func drainData() -> [String: AnyCodable] {
        lock.withLock {
            defer { data.removeAll() }
            return data
        }
    }
}
