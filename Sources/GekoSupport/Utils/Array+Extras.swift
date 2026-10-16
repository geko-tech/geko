import Foundation

public extension Array {
    func uniqued<T: Hashable>(by keyPath: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            seen.insert(keyPath(element)).inserted
        }
    }
}
