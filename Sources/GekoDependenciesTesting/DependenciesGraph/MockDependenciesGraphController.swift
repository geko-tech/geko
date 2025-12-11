import Foundation
import GekoGraph
import GekoGraphTesting

import struct ProjectDescription.AbsolutePath

@testable import GekoDependencies

public final class MockDependenciesGraphController: DependenciesGraphControlling {
    public init() {}

    var invokedSave = false
    var saveStub: ((GekoGraph.DependenciesGraph, AbsolutePath) throws -> Void)?

    public func save(_ dependenciesGraph: GekoGraph.DependenciesGraph, to path: AbsolutePath) throws {
        invokedSave = true
        try saveStub?(dependenciesGraph, path)
    }

    var invokedLoad = false
    var loadStub: ((AbsolutePath) throws -> GekoGraph.DependenciesGraph)?

    public func load(at path: AbsolutePath) throws -> GekoGraph.DependenciesGraph {
        invokedLoad = true
        return try loadStub?(path) ?? DependenciesGraph.test()
    }

    var invokedClean = false
    var cleanStub: ((AbsolutePath) throws -> Void)?

    public func clean(at path: AbsolutePath) throws {
        invokedClean = true
        try cleanStub?(path)
    }
}
