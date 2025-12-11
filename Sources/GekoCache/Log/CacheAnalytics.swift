import Foundation
import GekoSupport

public enum CacheAnalytics {
    private static let localCacheTargetsHitsLock = NSLock()
    public private(set) static var localCacheTargetsHits: Set<String> = []
    public static func addLocalCacheTargetHit(_ name: String) {
        localCacheTargetsHitsLock.lock()
        localCacheTargetsHits.insert(name)
        localCacheTargetsHitsLock.unlock()
    }

    private static let remoteCacheTargetsHitsLock = NSLock()
    public private(set) static var remoteCacheTargetsHits: Set<String> = []
    public static func addRemoteCacheTargetHit(_ name: String) {
        remoteCacheTargetsHitsLock.lock()
        remoteCacheTargetsHits.insert(name)
        remoteCacheTargetsHitsLock.unlock()
    }

    public static var cacheableTargets: [String] = []
    public static var cacheableTargetsCount: Int = 0
    public static var currentHashableBuildTargetsCount: Int = 0

    public static func cacheHit() -> String {
        let cachedTargets = currentHashableBuildTargetsCount - cacheableTargetsCount
        guard cachedTargets > 0, currentHashableBuildTargetsCount > 0 else { return "0" }
        let cacheHit = (Double(cachedTargets) / Double(currentHashableBuildTargetsCount)) * 100
        return String(format: "%.2f", cacheHit)
    }
}
