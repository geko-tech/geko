import Foundation
import Logging

public struct JSONLogHandler: LogHandler {
    public var logLevel: Logger.Level = .debug
    public var metadata: Logger.Metadata = Logger.Metadata()
    public let label: String
    
    public init(label: String) {
        self.label = label
    }
    
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        switch level {
        case .warning:
            CommandOutputStore.shared.appendWarning(message.description)
        case .error, .critical:
            CommandOutputStore.shared.appendError(message.description)
        default:
            break
        }
    }
    
    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}
