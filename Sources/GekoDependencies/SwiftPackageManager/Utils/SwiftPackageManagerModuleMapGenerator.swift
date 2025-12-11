import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoSupport
import GekoCore

/// The type of modulemap file
public enum ModuleMap: Equatable {
    /// No headers and hence no modulemap file
    case none
    /// Custom modulemap file provided in SPM package
    case custom(moduleMapPath: AbsolutePath, umbrellaHeaderPath: AbsolutePath?)
    /// Umbrella header provided in SPM package
    case header(moduleMapPath: AbsolutePath, umbrellaHeaderPath: AbsolutePath)
    /// No umbrella header provided in SPM package, define umbrella directory
    case directory(moduleMapPath: AbsolutePath, umbrellaDirectory: AbsolutePath)

    var moduleMapPath: AbsolutePath? {
        switch self {
        case let .custom(path, _):
            return path
        case let .header(path, _):
            return path
        case let .directory(path, _):
            return path
        case .none:
            return nil
        }
    }

    /// Name of the module map file recognized by the Clang and Swift compilers.
    public static let filename = "module.modulemap"
}

/// Protocol that allows to generate a modulemap for an SPM target.
/// It implements the Swift Package Manager logic
/// [documented here](https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#creating-c-language-targets)
/// and
/// [implemented here](https://github.com/apple/swift-package-manager/blob/main/Sources/PackageLoading/ModuleMapGenerator.swift).
public protocol SwiftPackageManagerModuleMapGenerating {
    func generate(
        packageDirectory: AbsolutePath,
        moduleName: String,
        publicHeadersPath: AbsolutePath
    ) throws -> ModuleMap
}

public final class SwiftPackageManagerModuleMapGenerator: SwiftPackageManagerModuleMapGenerating {
    private let contentHasher: ContentHashing
    
    public init(
        contentHasher: ContentHashing = ContentHasher()
    ) {
        self.contentHasher = contentHasher
    }

    public func generate(
        packageDirectory: AbsolutePath,
        moduleName: String,
        publicHeadersPath: AbsolutePath
    ) throws -> ModuleMap {
        let umbrellaHeaderPath = publicHeadersPath.appending(component: moduleName + ".h")
        let nestedUmbrellaHeaderPath = publicHeadersPath.appending(component: moduleName).appending(component: moduleName + ".h")
        let sanitizedModuleName = moduleName.sanitizedModuleName
        let customModuleMapPath = try customModuleMapPath(publicHeadersPath: publicHeadersPath)
        let generatedModuleMapPath: AbsolutePath

        if publicHeadersPath.pathString.contains("\(Constants.DependenciesDirectory.packageBuildDirectoryName)/\(Constants.DependenciesDirectory.spmCheckouts)") {
            generatedModuleMapPath = packageDirectory.parentDirectory.parentDirectory.appending(components: [
                Constants.DerivedDirectory.dependenciesDerivedDirectory,
                sanitizedModuleName,
                "\(sanitizedModuleName).modulemap"
            ])
        } else {
            generatedModuleMapPath = packageDirectory.appending(components: [
                Constants.DerivedDirectory.name,
                "\(sanitizedModuleName).modulemap"
            ])
        }
        
        if !FileHandler.shared.exists(generatedModuleMapPath.parentDirectory) {
            try FileHandler.shared.createFolder(generatedModuleMapPath.parentDirectory)
        }
        
        if FileHandler.shared.exists(umbrellaHeaderPath) {
            if let customModuleMapPath {
                return .custom(moduleMapPath: customModuleMapPath, umbrellaHeaderPath: umbrellaHeaderPath)
            }
            
            try writeIfDifferent(
                moduleMapContent: umbrellaHeaderModuleMap(
                    umbrellaHeaderPath: umbrellaHeaderPath,
                    sanitizedModuleName: sanitizedModuleName
                ),
                to: generatedModuleMapPath,
                atomically: true
            )
            
            // If 'PublicHeadersDir/ModuleName.h' exists, then use it as the umbrella header.
            return .header(moduleMapPath: generatedModuleMapPath, umbrellaHeaderPath: umbrellaHeaderPath)
        } else if FileHandler.shared.exists(nestedUmbrellaHeaderPath) {
            if let customModuleMapPath {
                return .custom(moduleMapPath: customModuleMapPath, umbrellaHeaderPath: nestedUmbrellaHeaderPath)
            }
            try writeIfDifferent(
                moduleMapContent: umbrellaHeaderModuleMap(
                    umbrellaHeaderPath: nestedUmbrellaHeaderPath,
                    sanitizedModuleName: sanitizedModuleName
                ),
                to: generatedModuleMapPath,
                atomically: true
            )
            
            // If 'PublicHeadersDir/ModuleName/ModuleName.h' exists, then use it as the umbrella header.
            return .header(moduleMapPath: generatedModuleMapPath, umbrellaHeaderPath: nestedUmbrellaHeaderPath)
        } else if let customModuleMapPath {
            // User defined modulemap exists, use it
            return .custom(moduleMapPath: customModuleMapPath, umbrellaHeaderPath: nil)
        } else if FileHandler.shared.exists(publicHeadersPath) {
            if try FileHandler.shared.glob(publicHeadersPath, patterns: ["**/*.h", "*.h"], exclude: []).isEmpty {
                return .none
            }
            
            // Otherwise, consider the public headers folder as umbrella directory
            let generatedModuleMapContent =
                """
                module \(sanitizedModuleName) {
                    umbrella "\(publicHeadersPath.pathString)"
                    export *
                }

                """
            try writeIfDifferent(moduleMapContent: generatedModuleMapContent, to: generatedModuleMapPath, atomically: true)
            return .directory(moduleMapPath: generatedModuleMapPath, umbrellaDirectory: publicHeadersPath)
        } else {
            return .none
        }
    }
    
    /// Write our modulemap to disk if it is distinct from what already exists.
    /// This addresses an issue with dependencies that are included in a precompiled header.
    /// - Parameters:
    ///   - moduleMapContent: contents of the moduleMap file to write
    ///   - path: destination to write file contents to
    ///   - atomically: whether to write atomically
    private func writeIfDifferent(moduleMapContent: String, to path: AbsolutePath, atomically _: Bool) throws {
        let newContentHash = try contentHasher.hash(moduleMapContent)
        let currentContentHash = try? contentHasher.hash(path: path)
        if currentContentHash != newContentHash {
            try FileHandler.shared.write(moduleMapContent, path: path, atomically: true)
        }
    }

    private func customModuleMapPath(publicHeadersPath: AbsolutePath) throws -> AbsolutePath? {
        guard FileHandler.shared.exists(publicHeadersPath) else { return nil }

        let moduleMapPath = try RelativePath(validating: ModuleMap.filename)
        let publicHeadersFolderContent = try FileHandler.shared.contentsOfDirectory(publicHeadersPath)

        if publicHeadersFolderContent.contains(publicHeadersPath.appending(moduleMapPath)) {
            return publicHeadersPath.appending(moduleMapPath)
        } else if publicHeadersFolderContent.count == 1,
                  let nestedHeadersPath = publicHeadersFolderContent.first,
                  FileHandler.shared.isFolder(nestedHeadersPath),
                  FileHandler.shared.exists(nestedHeadersPath.appending(moduleMapPath))
        {
            return nestedHeadersPath.appending(moduleMapPath)
        } else {
            return nil
        }
    }
    
    private func umbrellaHeaderModuleMap(umbrellaHeaderPath: AbsolutePath, sanitizedModuleName: String) -> String {
        """
        framework module \(sanitizedModuleName) {
          umbrella header "\(umbrellaHeaderPath.pathString)"

          export *
          module * { export * }
        }
        """
    }
}
