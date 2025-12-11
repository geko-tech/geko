import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoSupport

public final class MockDeveloperEnvironment: DeveloperEnvironmenting {
    
    public var invokedDerivedDataDirectoryGetter = false
    public var invokedDerivedDataDirectoryGetterCount = 0
    public var stubbedDerivedDataDirectory: DerivedDataPath!
    
    public func derivedDataDirectory(for projectPath: AbsolutePath) -> GekoSupport.DerivedDataPath {
        invokedDerivedDataDirectoryGetter = true
        invokedDerivedDataDirectoryGetterCount += 1
        return stubbedDerivedDataDirectory
    }

    public var invokedArchitectureGetter = false
    public var invokedArchitectureGetterCount = 0
    public var stubbedArchitecture: MacArchitecture!

    public var architecture: MacArchitecture {
        invokedArchitectureGetter = true
        invokedArchitectureGetterCount += 1
        return stubbedArchitecture
    }
}
