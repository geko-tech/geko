import Foundation
import GekoSupport

public final class ManifestLoaderFactory {
    public init() { }

    public func createManifestLoader() -> ManifestLoading {
        return CompiledManifestLoader()
    }
}
