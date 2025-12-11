import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
import XcodeProj
import GekoGenerator
import GekoGraph
import AnyCodable

enum BumpServiceError: FatalError {
    case xcodeprojNotFound
    case multipleXcodeprojects
    case didNotPassAnyOptions
    
    var description: String {
        switch self {
        case .xcodeprojNotFound:
            return "The xcodeproj cannot be found"
        case .multipleXcodeprojects:
            return "There are multiple projects in this directory. Select one by specifying the --path parameter"
        case .didNotPassAnyOptions:
            return "You didn't pass any options"
        }
    }
    
    var type: ErrorType {
        return .abort
    }
}

final class BumpService {
    
    // MARK: - Run
    
    func run(
        path: String?,
        buildNumber: String?,
        version: String?
    ) async throws {
        guard buildNumber != nil || version != nil else {
            throw BumpServiceError.didNotPassAnyOptions
        }
        let path = try self.path(path)
        let xcodeProj = try XcodeProj(pathString: path.pathString)
        var infoPlistPaths = [String]()
        
        try xcodeProj.pbxproj.nativeTargets.forEach { pbxTarget in
            let infoPlistFilePaths = try Set(try xcodeProj.pbxproj.resolveBuildSetting(
                key: "INFOPLIST_FILE",
                for: pbxTarget,
                resolveAgaintsXCConfig: true,
                projectPath: path.parentDirectory
            )
            .map { try $0.value.stringValue() })
            .filter { !$0.isEmpty }
            .map {
                try AbsolutePath(
                    validating: $0,
                    relativeTo: FileHandler.shared.currentPath
                )
            }
            
            try infoPlistFilePaths.forEach { path in
                var plist: [String: AnyCodable] = try FileHandler.shared.readPlistFile(path)
                if let buildNumber {
                    plist["CFBundleVersion"] = AnyCodable(stringLiteral: buildNumber)
                }
                if let version {
                    plist["CFBundleShortVersionString"] = AnyCodable(stringLiteral: version)
                }
                try FileHandler.shared.writePlistFile(plist, path: path)
                infoPlistPaths.append(path.pathString)
            }
        }
        if let buildNumber {
            logger.info("Successfully updated build number \(buildNumber)")
        }
        if let version {
            logger.info("Successfully updated version \(version)")
        }
        logger.info("Modified info plists:\n\(infoPlistPaths.joined(separator: "\n"))")
    }
    
    // MARK: - Helpers
    
    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            let xcodeprojectPaths = FileHandler.shared.glob(FileHandler.shared.currentPath, glob: "*.xcodeproj")
            guard xcodeprojectPaths.count <= 1 else {
                throw BumpServiceError.multipleXcodeprojects
            }
            guard let xcodeprojectPath = xcodeprojectPaths.first else {
                throw BumpServiceError.xcodeprojNotFound
            }
            return xcodeprojectPath
        }
    }
}
