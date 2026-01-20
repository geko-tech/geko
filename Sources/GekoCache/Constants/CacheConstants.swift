import Foundation
import GekoGraph
import ProjectDescription

public enum CacheConstants {
    /// Default name of temporary created cache project
    public static let cacheProjectName = "GekoCache"
    public static let cachableProducts: Set<Product> = [.framework, .staticFramework, .bundle]
    public static let xcframeworkOutputFolderName = "XCFrameworks"
    public static let bundleOutputFolderName = "Bundles"
}
