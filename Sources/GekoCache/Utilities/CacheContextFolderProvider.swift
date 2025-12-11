import Foundation
import GekoSupport
import GekoGraph

public protocol CacheContextFolderProviding {
    
    func contextFolderName() -> String
}

public final class CacheContextFolderProvider: CacheContextFolderProviding {
    // MARK: - Attributes
    
    private let profile: GekoGraph.Cache.Profile
    private let developerEnvironment: DeveloperEnvironmenting
    
    // MARK: - Initialization
    
    public init(
        profile: GekoGraph.Cache.Profile,
        developerEnvironment: DeveloperEnvironmenting = DeveloperEnvironment.shared
    ) {
        self.profile = profile
        self.developerEnvironment = developerEnvironment
    }
    
    // MARK: - CacheContextFolderProviding

    public func contextFolderName() -> String {
        let configuration = profile.configuration.replacingOccurrences(of: " ", with: "-")
        return "\(configuration)-\(profile.name)"
    }
}
