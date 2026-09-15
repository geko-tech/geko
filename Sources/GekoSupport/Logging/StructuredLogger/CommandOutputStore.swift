import AnyCodable
import Foundation

/// Collects diagnostics and command data for the final JSON response.
///
/// Commands and services can add output while they run. `GekoCommand` reads
/// all collected values once the command finishes and renders the response.
public protocol CommandOutputStoring {
    /// Adds a warning to the final JSON response.
    func appendWarning(_ message: String)

    /// Adds an error to the final JSON response.
    func appendError(_ message: String)

    /// Stores a value under a top-level command output key.
    func set<T: Encodable>(_ key: CommandOutputKey, value: T)

    /// Stores a value inside the section assigned to the given key.
    func set<Key: CommandOutputSectionKey, Value: Encodable>(_ key: Key, value: Value)

    /// Returns all collected output and clears the store for the next use.
    func drain() -> CommandOutputSnapshot
}

public struct CommandOutputSnapshot {
    public let warnings: [CommandDiagnostic]
    public let errors: [CommandDiagnostic]
    public let data: [String: AnyEncodable]
}

/// Thread-safe storage used to build the final command output.
public final class CommandOutputStore: CommandOutputStoring {
    public static let shared: CommandOutputStoring = CommandOutputStore()

    private let lock = NSLock()

    private var warnings: [CommandDiagnostic] = []
    private var errors: [CommandDiagnostic] = []
    private var data: [String: AnyEncodable] = [:]

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

    public func set<T: Encodable>(
        _ key: CommandOutputKey,
        value: T
    ) {
        lock.withLock {
            data[key.rawValue] = AnyEncodable(value)
        }
    }

    public func set<Key: CommandOutputSectionKey, Value: Encodable>(
        _ key: Key,
        value: Value
    ) {
        lock.withLock {
            let section = Key.section.rawValue
            var sectionData = data[section]?.value as? [String: AnyEncodable] ?? [:]
            sectionData[key.rawValue] = AnyEncodable(value)
            data[section] = AnyEncodable(sectionData)
        }
    }

    public func drain() -> CommandOutputSnapshot {
        lock.withLock {
            defer {
                warnings.removeAll()
                errors.removeAll()
                data.removeAll()
            }
            return CommandOutputSnapshot(
                warnings: warnings,
                errors: errors,
                data: data
            )
        }
    }
}
