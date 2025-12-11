import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoSupport

public protocol ResourceLocating: AnyObject {
    func projectDescription() throws -> AbsolutePath
    func cliPath() throws -> AbsolutePath
}

enum ResourceLocatingError: FatalError {
    case notFound(String)

    var description: String {
        switch self {
        case let .notFound(name):
            return "Couldn't find resource named \(name)"
        }
    }

    var type: ErrorType {
        switch self {
        default:
            return .bug
        }
    }
}

public final class ResourceLocator: ResourceLocating {
    public init() {}

    // MARK: - ResourceLocating

    public func projectDescription() throws -> AbsolutePath {
        try frameworkPath("ProjectDescription")
    }

    public func cliPath() throws -> AbsolutePath {
        try toolPath("geko")
    }

    // MARK: - Fileprivate

    private func frameworkPath(_ name: String) throws -> AbsolutePath {
        let frameworkNames = ["lib\(name).dylib", "\(name).framework", "PackageFrameworks/\(name).framework", "lib\(name).so"]
#if os(macOS)
        let bundlePath = try AbsolutePath(validatingAbsolutePath: Bundle(for: CompiledManifestLoader.self).bundleURL.path)
#else
        let bundlePath = try AbsolutePath(validatingAbsolutePath: Bundle.main.bundleURL.path)
#endif

        var paths: [AbsolutePath] = [
            bundlePath,
            bundlePath.parentDirectory,
            /**
                == Homebrew directory structure ==
                x.y.z/
                   bin/
                       geko
                   lib/
                       ProjectDescription.framework
                       ProjectDescription.framework.dSYM
                */
            bundlePath.parentDirectory.appending(component: "lib"),
        ]
        if let frameworkSearchPaths = ProcessEnv.vars["GEKO_FRAMEWORK_SEARCH_PATHS"]?.components(separatedBy: " ")
            .filter({ !$0.isEmpty })
        {
            paths.append(
                contentsOf: try frameworkSearchPaths.map { try AbsolutePath(validatingAbsolutePath: $0) }
            )
        }
        let candidates = try paths.flatMap { path in
            try frameworkNames.map { path.appending(try RelativePath(validating: $0)) }
        }
        guard let frameworkPath = candidates.first(where: { FileHandler.shared.exists($0) }) else {
            throw ResourceLocatingError.notFound(name)
        }
        return frameworkPath
    }

    private func toolPath(_ name: String) throws -> AbsolutePath {
        let bundlePath = try AbsolutePath(validatingAbsolutePath: Bundle(for: CompiledManifestLoader.self).bundleURL.path)
        let paths = [bundlePath, bundlePath.parentDirectory]
        let candidates = paths.map { $0.appending(component: name) }
        guard let path = candidates.first(where: { FileHandler.shared.exists($0) }) else {
            throw ResourceLocatingError.notFound(name)
        }
        return path
    }
}
