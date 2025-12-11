import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
import GekoGraph

public struct SwiftInterfaceMetadata {
    public let fileName: String
    public let flags: [String]
    public let ignorableFlags: [String]
    public let path: AbsolutePath
}

enum SwiftInterfaceMetadataProviderError: FatalError, Equatable {
    case parsingError(AbsolutePath)

    var description: String {
        switch self {
        case let .parsingError(path):
            return "Couldn't parse swiftinterface data to string with utf8 encoding at path \(path.pathString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .parsingError:
            return .abort
        }
    }
}

public protocol SwiftInterfaceMetadataProviding {
    func loadMetadata(at path: AbsolutePath) throws -> SwiftInterfaceMetadata
}

public final class SwiftInterfaceMetadataProvider: SwiftInterfaceMetadataProviding {
    // MARK: - Constants
    private enum Constants {
        static let moduleFlagsPrefix = "// swift-module-flags: "
        static let ignorableFlagsPrefix = "// swift-module-flags-ignorable: "
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - SwiftInterfaceMetadataProviding
    
    public func loadMetadata(at path: AbsolutePath) throws -> SwiftInterfaceMetadata {
        let rawData = try Data(contentsOf: path.asURL)
        guard let rawString = String(data: rawData, encoding: .utf8) else {
            throw SwiftInterfaceMetadataProviderError.parsingError(path)
        }
        let fileName = path.basenameWithoutExt
        let moduleArguments = moduleFlags(rawString, prefix: Constants.moduleFlagsPrefix)
        let moduleIgnorableArguments = moduleFlags(rawString, prefix: Constants.ignorableFlagsPrefix)

        return SwiftInterfaceMetadata(
            fileName: fileName,
            flags: moduleArguments,
            ignorableFlags: moduleIgnorableArguments,
            path: path
        )
    }
    
    // MARK: - Private
    
    private func moduleFlags(_ swiftInterface: String, prefix: String) -> [String] {
        let strings = swiftInterface.components(separatedBy: .newlines)
        guard let argLine = strings.first(where: { $0.hasPrefix(prefix) }) else {
            return []
        }
        return argLine.dropPrefix(prefix).components(separatedBy: " ")
    }
}
