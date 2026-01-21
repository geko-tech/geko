import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension CocoapodsDependencies {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< dependencies.count {
            try dependencies[i].resolvePaths(generatorPaths: generatorPaths)
        }

        var newLocalPodspecs: [FilePath: [FilePath]] = [:]
        var seenDependencies = Set(dependencies)
        try localPodspecs?.forEach{ rootDir, podspecPaths in
            let resolvedRootDirPath = try generatorPaths.resolve(path: rootDir)
            podspecPaths.forEach { podspecPath in
                FileHandler.shared.glob(
                    resolvedRootDirPath, glob: podspecPath.pathString
                ).forEach { fullPath in
                    // SomeName.podspec.json
                    if let name = fullPath.basenameWithoutExt.split(separator: ".").first {
                        let dep = Dependency.path(name: String(name), path: resolvedRootDirPath)
                        if !seenDependencies.contains(dep) {
                            dependencies.append(dep)
                            seenDependencies.insert(dep)
                        }
                    }
                }
            }
        }

        self.localPodspecs = newLocalPodspecs
    }
}

extension CocoapodsDependencies.Dependency: Hashable {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case .cdn:
            break
        case .git:
            break
        case let .path(name, path):
            self = .path(name: name, path: try generatorPaths.resolve(path: path))
        case .gitRepo:
            break
        }
    }
}
