import Foundation

// MARK: - https://stackoverflow.com/a/39170072

extension Dictionary where Value: Any {
    public func isEqual(to otherDict: [Key: Any]) -> Bool {
        #if os(macOS)
        NSDictionary(dictionary: self).isEqual(to: NSDictionary(dictionary: otherDict))
        #else
        let dict = [AnyHashable: Any](uniqueKeysWithValues: otherDict.map { (AnyHashable($0.key), $0.value) })
        return NSDictionary(dictionary: self).isEqual(to: dict)
        #endif
    }
}
