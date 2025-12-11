import Foundation
import GekoSupport

let logger = Logger(label: "io.geko.generator")

final class ClearingLogger {
    let queue = DispatchQueue(label: "io.geko.generator.clearinglogger.queue")

    func info(_ message: String) {
        queue.async {
            print("\u{1B}[2K\r\(message)", terminator: "")
            fflush(stdout)
        }
    }
}

let clearingLogger = ClearingLogger()
