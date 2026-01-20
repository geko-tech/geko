import Foundation
import GekoGraph
import ProjectDescription

public protocol CocoapodsApphostDependencyResolving {
    func resolve(appHostName: String) throws -> TargetDependency
}

public final class CocoapodsApphostDependencyResolver: CocoapodsApphostDependencyResolving {
    private let localPodspecNameToPath: [String: AbsolutePath]
    private let externalDependencies: [String: [TargetDependency]]

    public init(localPodspecNameToPath: [String: AbsolutePath], externalDependencies: [String: [TargetDependency]]) {
        self.localPodspecNameToPath = localPodspecNameToPath
        self.externalDependencies = externalDependencies
    }

    public func resolve(appHostName: String) throws -> ProjectDescription.TargetDependency {
        let components = appHostName.components(separatedBy: "/")
        let podName = components[0]
        let appTargetName = components.joined(separator: "-") // PodName/AppHost -> PodName-AppHost
        if let localPodspecPath = localPodspecNameToPath[podName] {
            return .project(target: appTargetName, path: localPodspecPath)
        }
        if let dependencies = externalDependencies[podName] {
            for dependency in dependencies {
                if case .project(appTargetName, let path, _, _) = dependency {
                    return .project(target: appTargetName, path: path)
                }
            }
        }
        return .target(name: appTargetName)
    }
}
