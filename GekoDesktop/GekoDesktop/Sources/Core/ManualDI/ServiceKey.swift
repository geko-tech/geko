public struct ServiceKey {
    public let serviceType: Any.Type
    public let name: String?
    
    public init(serviceType: Any.Type, name: String? = nil) {
        self.serviceType = serviceType
        self.name = name
    }
}

// MARK: - Hashable

extension ServiceKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(serviceType).hash(into: &hasher)
        name?.hash(into: &hasher)
    }
}

// MARK: - Equatable

extension ServiceKey: Equatable {
    public static func == (lhs: ServiceKey, rhs: ServiceKey) -> Bool {
        return lhs.serviceType == rhs.serviceType
            && lhs.name == rhs.name
    }
}

