import Foundation

public final class ClearingLogger {
    private let queue = DispatchQueue(label: "io.geko.spinner.clearinglogger.\(UUID().uuidString)")
    
    public init() {}

    public func info(_ message: String) {
        queue.async {
            print("\u{1B}[2K\r\(message)", terminator: "")
            fflush(stdout)
        }
    }
}
