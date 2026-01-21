import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol CocoapodsLocationProviding {
    func shellCommand(config: Config) throws -> [String]
}

public final class CocoapodsLocationProvider: CocoapodsLocationProviding {
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - CocoapodsLocationProviding
    
    public func shellCommand(config: Config) throws -> [String] {
        if config.cocoapodsUseBundler {
            let bundlePath = try System.shared.which("bundle")
            return [bundlePath, "exec", "pod"]
        } else {
            let podPath = try System.shared.which("pod")
            return [podPath]
        }
    }
}
