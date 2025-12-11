import Foundation
import GekoCocoapods
import PubGrub
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.CocoapodsLockfile
import GekoSupport
import Yams

public enum CocoapodsLockfileError: FatalError {
    case sourcesChanges(new: [String], removed: [String])
    case podsChanges([String])

    private static let firstLine = "Detected Cocoapods.lock changes during deployment mode."
    private static let lastLine = "Consider running 'geko fetch' without --deployment flag."

    public var description: String {
        switch self {
        case let .sourcesChanges(new, removed):
            var msg = "\(Self.firstLine)\nSources were changed\n"
            if new.isEmpty {
                msg += "New sources:\n"
                for source in new {
                    msg += " · \(source)"
                }
            }
            if removed.isEmpty {
                msg += "Removed sources:\n"
                for source in removed {
                    msg += " · \(source)"
                }
            }
            msg += "\n"
            msg += Self.lastLine
            return msg
        case let .podsChanges(errors):
            return "\(Self.firstLine)\n\(errors.joined(separator: "\n"))\n\(Self.lastLine)"
        }
    }

    public var type: ErrorType {
        return .abort
    }
}

public typealias CocoapodsLockfile = ProjectDescription.CocoapodsLockfile

// MARK: - Interaction

extension CocoapodsLockfile {
    func version(for package: String) -> CocoapodsVersion? {
        // package can be a subspec, for example 'abseil/time', so we need
        // to get a spec name
        let package = package.components(separatedBy: "/")[0]

        for key in podsBySource.keys {
            guard let podData = podsBySource[key]!.pods[package] else {
                continue
            }

            return podData.version
        }

        return nil
    }
}

// MARK: - Serialization

extension CocoapodsLockfile {
    public static func load(from path: AbsolutePath) throws -> CocoapodsLockfile? {
        guard FileHandler.shared.exists(path) else {
            return nil
        }

        let data = try FileHandler.shared.readFile(path)

        return try from(data: data, context: .file(path: path))
    }

    public static func from(data: Data, context: ParseYamlContext) throws -> CocoapodsLockfile? {
        let lockfile: Lockfile = try parseYaml(data, context: context)

        return .init(podsBySource: lockfile)
    }

    static func from(dependenciesGraph: CocoapodsDependencyGraph) -> CocoapodsLockfile {
        var lockfile = CocoapodsLockfile(podsBySource: [:])

        for spec in dependenciesGraph.specs {
            let (spec, version, subspecs, source) = spec

            let newPodData = PodData(
                hash: source.isCDN ? spec.checksum : nil,
                version: version,

                subspecs: subspecs.isEmpty ? nil : Array(subspecs.sorted())
            )

            lockfile.podsBySource[source.lockfileUrl, default: makeSource(source)].pods[spec.name] = newPodData
        }

        return lockfile
    }

    func write(to path: AbsolutePath) throws {
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true
        let content = try encoder.encode(podsBySource)

        try FileHandler.shared.write(content, path: path, atomically: true)
    }
}

// MARK: - Comparison

extension CocoapodsLockfile {

    func compare(to new: CocoapodsLockfile) throws {
        try compareSources(to: new)
        try comparePods(to: new)
    }

    private func compareSources(to new: CocoapodsLockfile) throws {
        var newSources: [String] = []
        var removedSources: [String] = []

        for oldSource in self.podsBySource.keys {
            if new.podsBySource[oldSource] == nil {
                removedSources.append(oldSource)
            }
        }
        for newSource in new.podsBySource.keys {
            if self.podsBySource[newSource] == nil {
                newSources.append(newSource)
            }
        }

        if !newSources.isEmpty || !removedSources.isEmpty {
            throw CocoapodsLockfileError.sourcesChanges(new: newSources, removed: removedSources)
        }
    }

    private func comparePods(to new: CocoapodsLockfile) throws {
        var oldPods: [String: (source: String, PodData)] = [:]
        var newPods: [String: (source: String, PodData)] = [:]

        for (source, sourceData) in self.podsBySource {
            for (pod, podData) in sourceData.pods {
                oldPods[pod] = (source, podData)
            }
        }
        for (source, sourceData) in new.podsBySource {
            for (pod, podData) in sourceData.pods {
                newPods[pod] = (source, podData)
            }
        }

        enum PodChange {
            case source(old: String, new: String)
            case hash(old: String?, new: String?)
            case version(old: CocoapodsVersion, new: CocoapodsVersion)
            case subspecs(old: [String]?, new: [String]?)
        }

        var addedPods: [String] = []
        var removedPods: [String] = []
        var changedPods: [String: [PodChange]] = [:]

        // removed and changed
        for pod in oldPods.keys {
            guard let (newPodSource, newPodData) = newPods[pod] else {
                removedPods.append(pod)
                continue
            }
            let (oldPodSource, oldPodData) = oldPods[pod]!

            guard oldPodData != newPodData || oldPodSource != newPodSource else { continue }

            var changes: [PodChange] = []

            if oldPodData.version != newPodData.version {
                changes.append(.version(old: oldPodData.version, new: newPodData.version))
            }
            if oldPodSource != newPodSource {
                changes.append(.source(old: oldPodSource, new: newPodSource))
            }
            if oldPodData.hash != newPodData.hash {
                changes.append(.hash(old: oldPodData.hash, new: newPodData.hash))
            }
            if oldPodData.subspecs != newPodData.subspecs {
                changes.append(.subspecs(old: oldPodData.subspecs, new: newPodData.subspecs))
            }

            changedPods[pod] = changes
        }

        // new
        for pod in newPods.keys {
            if oldPods[pod] == nil {
                addedPods.append(pod)
            }
        }

        guard !addedPods.isEmpty || !changedPods.isEmpty || !removedPods.isEmpty else {
            return
        }

        var errors: [String] = []

        for addedPod in addedPods {
            errors.append(" · \(addedPod) has been added")
        }
        for removedPod in removedPods {
            errors.append(" · \(removedPod) has been removed")
        }
        for (changedPod, changes) in changedPods {
            errors.append(" · \(changedPod) has been changed:")
            for change in changes {
                switch change {
                case let .hash(old, new):
                    errors.append("     hash changed from '\(old ?? "none")' to '\(new ?? "none")'")
                case let .source(old, new):
                    errors.append("     source changed from '\(old)' to '\(new)'")
                case let .subspecs(old, new):
                    errors.append("     subspecs changed from '\(old ?? [])' to '\(new ?? [])'")
                case let .version(old, new):
                    errors.append("     version changed from '\(old)' to '\(new)'")
                }
            }
        }

        throw CocoapodsLockfileError.podsChanges(errors)
    }
}

private func makeSource(_ source: CocoapodsSource) -> CocoapodsLockfile.SourceData {
    switch source {
    case .cdn:
        return .init(type: .cdn, ref: nil, pods: [:])
    case let .git(_, ref):
        return .init(type: .git, ref: ref, pods: [:])
    case .path:
        return .init(type: .path, ref: nil, pods: [:])
    case .gitRepo:
        return .init(type: .gitRepo, ref: nil, pods: [:])
    }
}
