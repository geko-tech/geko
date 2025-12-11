import Foundation

public func weakify<T: AnyObject>(_ object: T) -> (() -> T?) {
    { [weak object] in object }
}

final public class DelegatesList<T>: Sequence {

    // Private
    private var delegates = Atomic<[() -> T?]>([])

    // MARK: - Public

    public init() { }

    public func addDelegate(_ delegate: @escaping () -> T?) {
        delegates.mutate {
            $0.append(delegate)
        }
    }

    public func removeDelegate(_ delegate: T) {
        let delegate = delegate as AnyObject
        delegates.mutate {
            $0.removeAll(where: { $0() as AnyObject === delegate })
        }
    }

    public var count: Int {
        delegates.value.count
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public func makeIterator() -> Array<T>.Iterator {
        delegates.value.compactMap { $0() }.makeIterator()
    }
}
