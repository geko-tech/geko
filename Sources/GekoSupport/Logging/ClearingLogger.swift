import Foundation

public final class ClearingLogger {
    private let queue = DispatchQueue(label: "io.geko.spinner.clearinglogger.\(UUID().uuidString)")
    private let ciChecker = CIChecker()
    
    public init() {}

    public func info(_ message: String) {
        guard !LogOutput.suppressesHumanOutput else { return }
        guard !ciChecker.isCI(), !isDebug, Environment.shared.isStandardOutputInteractive else {
            logger.notice(.init(stringLiteral: message))
            return
        }
        
        queue.async {
            print("\u{1B}[2K\r\(message)", terminator: "")
            fflush(stdout)
        }
    }
    
    private var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
