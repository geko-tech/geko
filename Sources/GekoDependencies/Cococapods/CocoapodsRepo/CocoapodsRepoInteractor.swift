import Collections
import Foundation
import GekoCocoapods
import GekoGraph
import ProjectDescription

enum CocoapodsRepoInteractorError: Error {
    case noAvailableVersions
    case specNotFound(String)
    case repoNotFound(String)
}

final class CocoapodsRepoInteractor {
    typealias Dependency = CocoapodsDependencies.Dependency

    private let repos: [String: CocoapodsRepo]
    private let repoPriority: [String]
    private let sourceFactory: (String) -> CocoapodsSource

    // source -> pod -> versions
    private var availableVersionsCache: [String: [String: [CocoapodsVersion]]] = [:]

    init(
        repos: [String: CocoapodsRepo],
        repoPriority: [String],
        sourceFactory: @escaping (String) -> CocoapodsSource
    ) {
        self.repos = repos
        self.repoPriority = repoPriority
        self.sourceFactory = sourceFactory
    }

    func findSource(for name: String, version: CocoapodsVersion) async throws -> String {
        for source in repoPriority {
            let versions = try await availableVersions(for: name, source: source)
            if versions.contains(version) {
                return source
            }
        }

        throw CocoapodsRepoInteractorError.specNotFound(name)
    }

    func availableVersions(
        for name: String,
        requirement: CocoapodsDependencies.Requirement? = nil,
        source: String? = nil
    ) async throws -> [CocoapodsVersion] {
        let result = try await availableVersions(source: source, name: name, requirement: requirement)
            .sorted()

        return result
    }

    private func availableVersions(
        source: String?,
        name: String,
        requirement: CocoapodsDependencies.Requirement? = nil
    ) async throws -> [CocoapodsVersion] {
        var result = Set<CocoapodsVersion>()

        let repoPriority = source.map { [$0] } ?? self.repoPriority

        for source in repoPriority {
            if let cached = availableVersionsCache[source]?[name] {
                result.formUnion(cached)
                continue
            }

            let versions = try await repos[source]!
                .availableVersions(forDependency: name).map(CocoapodsVersion.init(from:))
            result.formUnion(versions)

            availableVersionsCache[source, default: [:]][name] = versions
        }

        guard let requirement else {
            return Array(result)
        }

        return result.filter { $0.satisfies(requirement) }
    }

    func dependencies(
        for name: String,
        version: CocoapodsVersion,
        source: String? = nil
    ) async throws -> OrderedDictionary<String, CocoapodsVersionRange> {
        let components = name.components(separatedBy: "/")
        let specName = components[0]
        let resolvedSource: String
        if let source {
            resolvedSource = source
        } else {
            resolvedSource = try await findSource(for: specName, version: version)
        }

        guard let repo = repos[resolvedSource] else {
            throw CocoapodsRepoInteractorError.repoNotFound(resolvedSource)
        }

        let spec = try await repo.spec(dependency: specName, version: version)

        let deps = CocoapodsSpecInfoProvider.dependencies(
            for: spec, subspecPath: components.count == 1 ? "" : name
        )

        return try deps.reduce(into: [:]) { acc, kv in
            acc[kv.key] = try CocoapodsVersionRange.from(kv.value)
        }
    }

    func spec(for name: String, version: CocoapodsVersion, source: String?) async throws -> (CocoapodsSpec, CocoapodsSource) {
        let specName = name.components(separatedBy: "/")[0]

        let resolvedSource: String
        if let source {
            resolvedSource = source
        } else {
            resolvedSource = try await findSource(for: specName, version: version)
        }

        guard let repo = repos[resolvedSource] else {
            throw CocoapodsRepoInteractorError.repoNotFound(resolvedSource)
        }

        let spec = try await repo.spec(dependency: specName, version: version)

        return (spec, sourceFactory(resolvedSource))
    }
}

extension CocoapodsVersion {
    fileprivate func satisfies(_ requirement: CocoapodsDependencies.Requirement) -> Bool {
        switch requirement {
        case let .exact(req):
            let exactVersion = CocoapodsVersion(from: req)
            return self == exactVersion
        case let .atLeast(req):
            let minVersion = CocoapodsVersion(from: req)
            return self >= minVersion
        case let .upToNextMajor(req):
            let minVersion = CocoapodsVersion(from: req)
            let maxVersion = minVersion.bumpMajor()
            return self >= minVersion && self < maxVersion
        case let .upToNextMinor(req):
            let minVersion = CocoapodsVersion(from: req)
            let maxVersion = minVersion.bumpMinor()
            return self >= minVersion && self < maxVersion
        }
    }
}
