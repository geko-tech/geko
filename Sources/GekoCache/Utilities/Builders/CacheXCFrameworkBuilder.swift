import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

enum CacheXCFrameworkBuilderError: FatalError {
    case frameworksNotFound(targetName: String)
    
    var description: String {
        switch self {
        case let .frameworksNotFound(targetName):
            return "Couldn't find any framework to create xcframework for target \(targetName)"
        }
    }
    
    var type: ErrorType {
        switch self {
        case .frameworksNotFound:
            return .abort
        }
    }
}

public protocol CacheXCFrameworkBuilding {
    func build(
        platforms: [Platform],
        workDirectory: AbsolutePath,
        outputDirectory: AbsolutePath,
        cacheableTarget: [GraphTarget]
    ) async throws
}

public final class CacheXCFrameworkBuilder: CacheXCFrameworkBuilding {
    
    // MARK: - Attributes
    
    /// Xcode build controller instance to run xcodebuild commands.
    private let xcodeBuildController: XcodeBuildControlling
    
    // MARK: - Initialization
    
    public init(xcodeBuildController: XcodeBuildControlling) {
        self.xcodeBuildController = xcodeBuildController
    }
    
    // MARK: - CacheXCFrameworkBuilding
    
    public func build(
        platforms: [Platform],
        workDirectory: AbsolutePath,
        outputDirectory: AbsolutePath,
        cacheableTarget: [GraphTarget]
    ) async throws {
        let bundlesDir = outputDirectory.appending(component: CacheConstants.bundleOutputFolderName)
        if !FileHandler.shared.exists(bundlesDir) {
            try FileHandler.shared.createFolder(bundlesDir)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for target in cacheableTarget {
                guard target.target.product.isFramework else { continue }
                group.addTask {
                    try self.createXCFramework(
                        target: target,
                        platforms: platforms,
                        workDirectory: workDirectory,
                        outputDirectory: outputDirectory
                    )
                }
            }
            
            try await group.waitForAll()
        }
    }
}

// MARK: - Private

private extension CacheXCFrameworkBuilder {
    
    func createXCFramework(
        target: GraphTarget,
        platforms: [Platform],
        workDirectory: AbsolutePath,
        outputDirectory: AbsolutePath
    ) throws {
        var xcodeArguments = [XcodeBuildControllerCreateXCFrameworkArgument]()
        let productName = target.target.name
        for platform in platforms {
            let artifactsFoldersNames = "\(CacheConstants.cacheProjectName)-\(platform.caseValue)"
            let frameworkPath = workDirectory.appending(components: [
                artifactsFoldersNames,
                "\(productName).framework"
            ])
            if FileHandler.shared.exists(frameworkPath) {
                xcodeArguments.append(.framework(frameworkPath: frameworkPath))
            }
        }
        
        guard !xcodeArguments.isEmpty else {
            throw CacheXCFrameworkBuilderError.frameworksNotFound(targetName: productName)
        }
        
        let xcframeworkPath = outputDirectory.appending(components: [
            CacheConstants.xcframeworkOutputFolderName,
            "\(productName).xcframework"
        ])
        
        try xcodeBuildController.createXCFramework(
            arguments: xcodeArguments,
            output: xcframeworkPath
        )
    }
}
