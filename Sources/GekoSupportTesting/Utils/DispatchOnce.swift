import Foundation

extension DispatchQueue {
    private static var _once = [String]()
    private static let lock = NSLock()

    /**
     Executes a block of code, associated with a unique token, only once.  The code is thread safe and will
     only execute the code once even in the presence of multithreaded calls.

     - parameter token: A unique reverse DNS style name such as io.geko.<name> or a GUID
     - parameter block: Block to execute once
     */
    public final class func once(token: String, block: () -> Void) {
        lock.lock()

        if _once.contains(token) {
            lock.unlock()
            return
        }

        _once.append(token)
        lock.unlock()

        block()
    }
}
