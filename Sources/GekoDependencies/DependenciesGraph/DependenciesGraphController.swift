import Foundation
import GekoLoader
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

// MARK: - Dependencies Graph Controller Errors

enum DependenciesGraphControllerError: FatalError, Equatable {
    case failedToDecodeDependenciesGraph(_ errorDescription: String)
    case failedToEncodeDependenciesGraph
    /// Thrown when there is a `Dependencies.swift` but no `graph.json`
    case dependenciesWerentFetched

    var type: ErrorType {
        switch self {
        case .dependenciesWerentFetched, .failedToDecodeDependenciesGraph:
            return .abort
        case .failedToEncodeDependenciesGraph:
            return .bug
        }
    }

    var description: String {
        switch self {
        case .dependenciesWerentFetched:
            return "`Geko/Dependencies.swift` file is defined but `Geko/Dependencies/graph.json` cannot be found. Run `geko fetch` first"
        case let .failedToDecodeDependenciesGraph(errorDescription):
            return "Couldn't decode the DependenciesGraph from the serialized JSON file. Running `geko fetch` should solve the problem.\n\(errorDescription)"
        case .failedToEncodeDependenciesGraph:
            return "Couldn't encode the DependenciesGraph as a JSON file."
        }
    }
}

// MARK: - Dependencies Graph Controlling

/// A protocol that defines an interface to save and load the `DependenciesGraph` using a `graph.json` file.
public protocol DependenciesGraphControlling {
    /// Saves the `DependenciesGraph` as `graph.json`.
    /// - Parameters:
    ///   - dependenciesGraph: A model that will be saved.
    ///   - path: Directory where project's dependencies graph will be saved.
    func save(_ dependenciesGraph: GekoGraph.DependenciesGraph, to path: AbsolutePath) throws

    /// Loads the `DependenciesGraph` from `graph.json` file.
    /// - Parameter path: Directory where project's dependencies graph will be loaded.
    func load(at path: AbsolutePath) throws -> GekoGraph.DependenciesGraph

    /// Removes cached `graph.json`.
    /// - Parameter path: Directory where project's dependencies graph was saved.
    func clean(at path: AbsolutePath) throws
}

// MARK: - Dependencies Graph Controller

public final class DependenciesGraphController: DependenciesGraphControlling {
    private let rootDirectoryLocator: RootDirectoryLocating

    /// Default constructor.
    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()) {
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    public func save(_ dependenciesGraph: GekoGraph.DependenciesGraph, to path: AbsolutePath) throws {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted

        let encodedGraph = try jsonEncoder.encode(dependenciesGraph)

        guard let encodedGraphContent = String(data: encodedGraph, encoding: .utf8) else {
            throw DependenciesGraphControllerError.failedToEncodeDependenciesGraph
        }

        let graphPath = graphPath(at: path)

        try FileHandler.shared.touch(graphPath)
        try FileHandler.shared.write(encodedGraphContent, path: graphPath, atomically: true)
    }

    public func load(at path: AbsolutePath) throws -> GekoGraph.DependenciesGraph {
        // Search for the dependency graph at the root directory
        // This can be the directory of this project or in case of nested projects
        // the root of the overall project
        guard let rootDirectory = rootDirectoryLocator.locate(from: path) else {
            return .none
        }

        let dependenciesPath = dependenciesPath(at: rootDirectory)

        guard
            FileHandler.shared.exists(dependenciesPath)
                || FileHandler.shared.exists(
                    rootDirectory.appending(components: [
                        Constants.gekoDirectoryName,
                        Constants.DependenciesDirectory.packageSwiftName,
                    ])
                )
        else {
            return .none
        }

        let rootGraphPath = graphPath(at: rootDirectory)

        guard FileHandler.shared.exists(rootGraphPath) else {
            throw DependenciesGraphControllerError.dependenciesWerentFetched
        }

        let graphData = try FileHandler.shared.readFile(rootGraphPath)

        do {
            // return try JSONDecoder().decode(GekoGraph.DependenciesGraph.self, from: graphData)
            let graph: GekoGraph.DependenciesGraph = try parseJson(graphData, context: .file(path: rootGraphPath))
            let graphGeneratorPaths = GeneratorPaths(manifestDirectory: rootDirectory)
            let resolvedGraph = try graph.resolvePaths(generatorPaths: graphGeneratorPaths)
            return resolvedGraph
        } catch let error as FatalError {
            logger
                .debug(
                    "Failed to load dependencies graph, running `geko fetch` should solve the problem.\nError: \(error)"
                )
            throw DependenciesGraphControllerError.failedToDecodeDependenciesGraph(
                error.description
            )
        }
    }

    public func clean(at path: AbsolutePath) throws {
        let graphPath = graphPath(at: path)

        try FileHandler.shared.delete(graphPath)
    }

    // MARK: - Helpers

    private func dependenciesPath(at path: AbsolutePath) -> AbsolutePath {
        path
            .appending(components: [
                Constants.gekoDirectoryName,
                Constants.DependenciesDirectory.dependenciesFileName,
            ])
    }

    private func graphPath(at path: AbsolutePath) -> AbsolutePath {
        path
            .appending(components: [
                Constants.gekoDirectoryName,
                Constants.DependenciesDirectory.name,
                Constants.DependenciesDirectory.graphName,
            ])
    }
}
