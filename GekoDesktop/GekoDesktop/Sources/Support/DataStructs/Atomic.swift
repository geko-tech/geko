import Foundation

public final class Atomic<T> {
    
    private var _value: T
    private let lock = NSLock()
    
    // MARK: - Init

    public init(_ initialValue: T) {
        self._value = initialValue
    }
    
    // MARK: - Public

    public var value: T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    public func mutate(_ transform: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        transform(&_value)
    }
    
    // MARK: - Atomic of array

    static public func array(of type: T.Type) -> Atomic<[T]> {
        return Atomic<[T]>([T]())
    }
}
