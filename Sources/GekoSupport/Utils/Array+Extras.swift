import Foundation

public extension Array {
    func uniqued<T: Hashable>(by keyPath: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            seen.insert(keyPath(element)).inserted
        }
    }

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
