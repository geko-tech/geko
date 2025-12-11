public enum LogCategory: CaseIterable {
    case buildLogs
    case analytics
    case cacheHashes
    case inspect

    public var directoryName: String {
        switch self {
        case .buildLogs:
            return "BuildLogs"
        case .analytics:
            return "Analytics"
        case .cacheHashes:
            return "CacheHashes"
        case .inspect:
            return "Inspect"
        }
    }
}
