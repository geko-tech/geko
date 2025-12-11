import Foundation
import GekoSupport

public final class ManifestLoaderFactory {
    private let useCache: Bool
    public convenience init() {
        let cacheSetting = Environment.shared.gekoConfigVariables[Constants.EnvironmentVariables.cacheManifests, default: "1"]
        self.init(useCache: cacheSetting == "1")
    }

    public init(useCache: Bool) {
        self.useCache = useCache
    }

    public func createManifestLoader() -> ManifestLoading {
        return CompiledManifestLoader()
    }
}
