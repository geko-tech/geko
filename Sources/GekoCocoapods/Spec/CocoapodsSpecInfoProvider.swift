import Collections
import Foundation
import ProjectDescription

public final class CocoapodsSpecInfoProvider {
    let targetType: CocoapodsTargetType

    private let spec: CocoapodsSpec
    private let subspecs: Set<String>
    private let parent: CocoapodsSpecInfoProvider?

    public init(
        spec: CocoapodsSpec,
        subspecs: Set<String> = Set(),
        targetType: CocoapodsTargetType = .framework,
        inheritingFrom parent: CocoapodsSpecInfoProvider? = nil
    ) {
        self.spec = spec
        self.subspecs = subspecs
        self.targetType = targetType
        self.parent = parent
    }

    public var name: String { spec.name }
    public var version: String { spec.version }
    public var swiftVersion: String? { spec.swiftVersion }
    public var checksum: String { spec.checksum }
    public var source: CocoapodsSpec.Source { spec.source }
    public var targetName: String {
        switch targetType {
        case .framework:
            return name
        case .test:
            switch testType {
            case .none, .unit:
                return "\(parent?.name ?? "")-Unit-\(name)"
            case .ui:
                return "\(parent?.name ?? "")-UI-\(name)"
            }
        case .app:
            return "\(parent?.name ?? "")-\(name)"
        }
    }
    public var bundleNamePrefix: String { parent?.bundleNamePrefix ?? "\(spec.name)-" }
    public var moduleName: String? { spec.moduleName }
    public var staticFramework: Bool? { spec.staticFramework }
    public var requiresAppHost: Bool? { spec.requiresAppHost }
    public var appHostName: String? { spec.appHostName }
    public var testType: CocoapodsSpec.TestType? { spec.testType }
    public var testSpecs: [CocoapodsSpecInfoProvider] {
        spec.testSpecs.map {
            CocoapodsSpecInfoProvider(
                spec: $0,
                targetType: .test,
                inheritingFrom: self
            )
        }
    }
    public var appSpecs: [CocoapodsSpecInfoProvider] {
        spec.appSpecs.map {
            CocoapodsSpecInfoProvider(
                spec: $0,
                targetType: .app,
                inheritingFrom: self
            )
        }
    }
    public var scripts: [CocoapodsSpec.ScriptPhase]? { spec.scriptPhases }
    public var prepareCommand: String? { spec.prepareCommand }

    public func fold<Result, Value>(
        platform: CocoapodsPlatform = .default,
        keyPath: KeyPath<CocoapodsSpec, Value>,
        inherit: Bool = true,
        into: Result,
        nextPartialResult: (inout Result, Value) throws -> Void
    ) rethrows -> Result {
        var result = into

        if inherit, let parent {
            result = try parent.fold(
                platform: platform,
                keyPath: keyPath,
                inherit: inherit,
                into: into,
                nextPartialResult: nextPartialResult
            )
        }
        
        if case .default = platform {
            try nextPartialResult(&result, spec[keyPath: keyPath])
        } else {
            if let platformValues = spec.platformValues[platform.rawValue] {
                try nextPartialResult(&result, platformValues[keyPath: keyPath])
            }
        }

        var seenSubspecs: Set<String> = .init()

        for subspec in subspecs {
            let components = subspec.components(separatedBy: "/")

            for i in 0..<components.count {
                let subspecPath = components[0...i].joined(separator: "/")
                guard !seenSubspecs.contains(subspecPath) else { continue }

                guard let subspec = self.subspec(for: spec, path: subspecPath) else {
                    continue
                }
                
                if case .default = platform {
                    try nextPartialResult(&result, subspec[keyPath: keyPath])
                } else {
                    if let platformValues = subspec.platformValues[platform.rawValue] {
                        try nextPartialResult(&result, platformValues[keyPath: keyPath])
                    }
                }

                seenSubspecs.insert(subspecPath)
            }
        }

        return result
    }

    public func subspec(for spec: CocoapodsSpec, path: String) -> CocoapodsSpec? {
        let components = path.components(separatedBy: "/")

        if components.isEmpty {
            return nil
        }

        var subspec: CocoapodsSpec? = spec.subspecs.first(where: { $0.name == components[0] })

        var iter = components.makeIterator()
        _ = iter.next()
        while let next = iter.next() {
            subspec = subspec?.subspecs.first(where: { $0.name == next })
        }

        return subspec
    }

    public func destinations() -> Destinations {
        var destinations: Destinations = []
        if let _ = spec.platforms?.ios {
            destinations.formUnion(Destinations.iOS)
        }
        if let _ = spec.platforms?.osx {
            destinations.formUnion(Destinations.macOS)
        }
        if let _ = spec.platforms?.watchos {
            destinations.formUnion(Destinations.watchOS)
        }
        if let _ = spec.platforms?.tvos {
            destinations.formUnion(Destinations.tvOS)
        }
        if let _ = spec.platforms?.visionos {
            destinations.formUnion(Destinations.visionOS)
        }
        let parentDestinations = parent?.destinations() ?? []
        return destinations.isEmpty ? parentDestinations : destinations
    }

    public func supportedPlatforms() -> [CocoapodsPlatform] {
        var supportedPlatforms: [CocoapodsPlatform] = [.default]
        if let _ = spec.platforms?.ios {
            supportedPlatforms.append(.iOS)
        }
        if let _ = spec.platforms?.osx {
            supportedPlatforms.append(.macOS)
        }
        if let _ = spec.platforms?.watchos {
            supportedPlatforms.append(.watchOS)
        }
        if let _ = spec.platforms?.tvos {
            supportedPlatforms.append(.tvOS)
        }
        if let _ = spec.platforms?.visionos {
            supportedPlatforms.append(.visionOS)
        }
        return supportedPlatforms
    }

    public func deploymentTargets() -> DeploymentTargets {
        DeploymentTargets(
            iOS: deploymentTarget(platform: .iOS),
            macOS: deploymentTarget(platform: .macOS),
            watchOS: deploymentTarget(platform: .watchOS),
            tvOS: deploymentTarget(platform: .tvOS),
            visionOS: deploymentTarget(platform: .visionOS)
        )
    }
    
    public func deploymentTargets(platform: CocoapodsPlatform) -> DeploymentTargets {
        switch platform {
        case .default:
            return deploymentTargets()
        case .iOS:
            return DeploymentTargets(iOS: deploymentTarget(platform: .iOS))
        case .macOS:
            return DeploymentTargets(macOS: deploymentTarget(platform: .macOS))
        case .watchOS:
            return DeploymentTargets(watchOS: deploymentTarget(platform: .watchOS))
        case .tvOS:
            return DeploymentTargets(tvOS: deploymentTarget(platform: .tvOS))
        case .visionOS:
            return DeploymentTargets(visionOS: deploymentTarget(platform: .visionOS))
        }
    }
    
    private func deploymentTarget(platform: CocoapodsPlatform) -> String? {
        let target: String?

        switch platform {
        case .iOS:
            target = spec.platforms?.ios
        case .macOS:
            target = spec.platforms?.osx
        case .watchOS:
            target = spec.platforms?.watchos
        case .tvOS:
            target = spec.platforms?.tvos
        case .visionOS:
            target = spec.platforms?.visionos
        case .default:
            target = nil
        }

        return target ?? parent?.deploymentTarget(platform: platform)
    }

    public func sourceFiles() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let files = fold(platform: platform, keyPath: \.sourceFiles, inherit: false, into: Set<String>()) { result, sources in
                        sources.forEach { result.insert($0) }
                    }
                    return files.isEmpty ? nil : (platform, files)
                }
        )
    }

    public func excludeFiles() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let files = fold(platform: platform, keyPath: \.excludeFiles, inherit: false, into: Set<String>()) { result, exclude in
                        exclude.forEach { result.insert($0) }
                    }
                    return files.isEmpty ? nil : (platform, files)
                }
        )
    }

    public func privateHeaderFiles() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let headersFiles = fold(platform: platform, keyPath: \.privateHeaderFiles, inherit: false, into: Set<String>()) { result, headers in
                        headers.forEach { result.insert($0) }
                    }
                    return headersFiles.isEmpty ? nil : (platform, headersFiles)
                }
        )
    }

    public func publicHeaderFiles() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let headersFiles = fold(platform: platform, keyPath: \.publicHeaderFiles, inherit: false, into: Set<String>()) { result, headers in
                        headers.forEach { result.insert($0) }
                    }
                    return headersFiles.isEmpty ? nil : (platform, headersFiles)
                }
        )
    }

    public func projectHeaderFiles() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let headersFiles = fold(platform: platform, keyPath: \.projectHeaderFiles, inherit: false, into: Set<String>()) { result, headers in
                        headers.forEach { result.insert($0) }
                    }
                    return headersFiles.isEmpty ? nil : (platform, headersFiles)
                }
        )
    }
    public func headerMappingsDir() -> [CocoapodsPlatform: String] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    if platform == .default, let mappingDir = spec.headerMappingsDir {
                        return (platform, mappingDir)
                    } else if let mappingDir = spec.platformValues[platform.rawValue]?.headerMappingsDir {
                        return (platform, mappingDir)
                    }
                    return nil
                }
        )
    }

    public func compilerFlags() -> [CocoapodsPlatform: [String]] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    if platform == .default {
                        return (platform, spec.compilerFlags)
                    } else if let compilerFlags = spec.platformValues[platform.rawValue]?.compilerFlags {
                        return (platform, spec.compilerFlags + compilerFlags)
                    }
                    return nil
                }
        )
    }

    public func requiresArc(platform: CocoapodsPlatform) -> CocoapodsSpec.RequiresArc? {
        var arc: CocoapodsSpec.RequiresArc?
        if platform == .default {
            arc = spec.requiresArc
        } else {
            arc = spec.platformValues[platform.rawValue]?.requiresArc
        }
        guard case let .include(glob) = arc else { return arc }
        return .include(glob)
    }

    public func moduleMap(platform: CocoapodsPlatform) -> CocoapodsSpec.ModuleMap? {
        if platform == .default {
            return spec.moduleMap
        } else {
            return spec.platformValues[platform.rawValue]?.moduleMap ?? spec.moduleMap
        }
    }

    public func podTargetXCConfig() -> [CocoapodsPlatform: [String: CocoapodsSpec.SettingValue]] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let configs = fold(platform: platform, keyPath: \.podTargetXCConfig, into: [String: CocoapodsSpec.SettingValue]()) { result, xcconfig in
                        result.merge(xcconfig) { $1 }
                    }
                    return configs.isEmpty ? nil : (platform, configs)
                }
        )
    }

    public func infoPlist() -> [String: CocoapodsSpec.PlistValue] {
        // Does not support multiplatform by cocoapods
        fold(
            keyPath: \.infoPlist,
            into: [String: CocoapodsSpec.PlistValue]()
        ) { result, plist in
            result.merge(plist) { $1 }
        }
    }

    public func vendoredFrameworks() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformFrameworks = fold(platform: platform, keyPath: \.vendoredFrameworks, into: Set<String>()) { result, frameworks in
                        frameworks.forEach { result.insert($0) }
                    }
                    return platformFrameworks.isEmpty ? nil : (platform, platformFrameworks)
                }
        )
    }
    
    public func vendoredLibraries() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformLibraries = fold(platform: platform, keyPath: \.vendoredLibraries, into: Set<String>()) { result, libraries in
                        libraries.forEach { result.insert($0) }
                    }
                    return platformLibraries.isEmpty ? nil : (platform, platformLibraries)
                }
        )
    }

    public func frameworks() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformFrameworks = fold(platform: platform, keyPath: \.frameworks, into: Set<String>()) { result, frameworks in
                        result.formUnion(frameworks)
                    }
                    return platformFrameworks.isEmpty ? nil : (platform, platformFrameworks)
                }
        )
    }

    public func weakFrameworks() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformFrameworks = fold(platform: platform, keyPath: \.weakFrameworks, into: Set<String>()) { result, frameworks in
                        result.formUnion(frameworks)
                    }
                    return platformFrameworks.isEmpty ? nil : (platform, platformFrameworks)
                }
        )
    }

    public func libraries() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformFrameworks = fold(platform: platform, keyPath: \.libraries, into: Set<String>()) { result, frameworks in
                        result.formUnion(frameworks)
                    }
                    return platformFrameworks.isEmpty ? nil : (platform, platformFrameworks)
                }
        )
    }

    public func resources() -> [CocoapodsPlatform: Set<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let files = fold(platform: platform, keyPath: \.resources, inherit: false, into: Set<String>()) { result, resources in
                        resources.forEach { result.insert($0) }
                    }
                    return files.isEmpty ? nil : (platform, files)
                }
        )
    }

    public func resourceBundles() -> [CocoapodsPlatform: [String: Set<String>]] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformBundles = fold(platform: platform, keyPath: \.resourceBundles, inherit: false, into: [String: [String]]()) { result, bundles in
                        result.merge(bundles) { $1 + $0 }
                    }
                    
                    return platformBundles.isEmpty ? nil : (platform, platformBundles.mapValues { Set($0) })
                }
        )
    }

    public func dependencies() -> [CocoapodsPlatform: OrderedSet<String>] {
        Dictionary(
            uniqueKeysWithValues:
                supportedPlatforms().compactMap { platform in
                    let platformDeps = fold(platform: platform, keyPath: \.dependencies, inherit: false, into: OrderedSet<String>()) { result, deps in
                        guard let deps else { return }
                        result.formUnion(
                            deps.keys
                                .compactMap {
                                    guard let dep = $0.components(separatedBy: "/").first else {
                                        return nil
                                    }
                                    guard dep != spec.name else {
                                        return nil
                                    }
                                    return dep
                                }
                        )
                    }
                    return platformDeps.isEmpty ? nil : (platform, platformDeps)
                }
        )
    }

    public func dependenciesWithVersion() -> [String: [String]] {
        supportedPlatforms().reduce(into: [String: [String]]()) { merged, platform in
            let platformDeps = fold(platform: platform, keyPath: \.dependencies, inherit: false, into: [String: [String]]()) { result, deps in
                guard let deps else { return }
                deps.forEach { (key, value) in
                    guard let dep = key.components(separatedBy: "/").first, dep != spec.name else {
                        return
                    }
                    result[dep] = value
                }
            }

            for (dep, versions) in platformDeps {
                merged[dep, default: []].append(contentsOf: versions)
            }
        }
    }

    public func allFileGlobs() -> Set<String> {
        var result = Set<String>()

        let allSubspecs = allSubspecs()
        let specInfoProvider = CocoapodsSpecInfoProvider(spec: spec, subspecs: allSubspecs, inheritingFrom: parent)

        let keyPaths: [KeyPath<CocoapodsSpec, [String]>] = [
            \.sourceFiles,
            \.privateHeaderFiles,
            \.publicHeaderFiles,
            \.projectHeaderFiles,
            \.resources,
            \.vendoredFrameworks,
            \.preservePaths,
        ]

        for keyPath in keyPaths {
            supportedPlatforms().forEach {
                result.formUnion(
                    specInfoProvider
                        .fold(platform: $0, keyPath: keyPath, into: Set<String>()) { $0.formUnion($1) }
                )
            }
        }

        supportedPlatforms().forEach {
            result.formUnion(
                specInfoProvider.fold(platform: $0, keyPath: \.resourceBundles, into: Set<String>()) {
                    $0.formUnion($1.values.flatMap { v in v })
                }
            )
        }
        
        supportedPlatforms().forEach {
            if case let .include(moduleMapPath) = moduleMap(platform: $0) {
                result.insert(moduleMapPath)
            }
        }

        return result
    }

    public func allSubspecs() -> Set<String> {
        var result = Set<String>()

        for subspec in spec.subspecs {
            result.formUnion(allSubspecs(for: subspec))
        }

        return result
    }

    private func allSubspecs(for spec: CocoapodsSpec) -> Set<String> {
        var result = Set<String>([spec.name])

        for subspec in spec.subspecs {
            let partialResult = allSubspecs(for: subspec)
            for value in partialResult {
                result.insert("\(spec.name)/\(value)")
            }
        }

        return result
    }

    public func subspecs(for spec: CocoapodsSpec, subspecs: [String] = []) -> [CocoapodsSpec] {
        let subspecNames: [String]
        if !subspecs.isEmpty {
            subspecNames = subspecs
        } else if !spec.defaultSubspecs.isEmpty {
            subspecNames = spec.defaultSubspecs
        } else {
            return spec.subspecs
        }

        return spec.subspecs.filter { subspecNames.contains($0.name) }
    }
}

extension CocoapodsSpecInfoProvider {
    public static func dependencies(for spec: CocoapodsSpec, subspecPath: String = "") -> [String: [String]] {
        if subspecPath.isEmpty {
            var directDeps = spec.dependencies ?? [:]
            let subspecs: [String] =
                if spec.defaultSubspecs.isEmpty {
                    spec.subspecs.map(\.name)
                } else {
                    spec.defaultSubspecs
                }
            subspecs.forEach { directDeps["\(spec.name)/\($0)"] = [spec.version] }

            return directDeps
        }

        var iter: CocoapodsSpec? = spec
        let components = subspecPath.split(separator: "/")
        var componentsIter = components.dropFirst().makeIterator()
        var currentPath = ""
        var deps: [String: [String]] = [:]

        while let next = iter {
            deps.merge(next.dependencies ?? [:]) { $0 + $1 }
            if currentPath == "" {
                currentPath = next.name
            } else {
                currentPath += "/\(next.name)"
            }

            iter = componentsIter.next()
                .flatMap { component in next.subspecs.first(where: { $0.name == component }) }

            if iter == nil {
                for subspec in next.subspecs {
                    deps[currentPath + "/\(subspec.name)"] = [spec.version]
                }
            }
        }
        
        spec.platformValues.forEach { _, value in
            deps.merge(value.dependencies ?? [:]) { $0 + $1 }
        }

        return deps
    }
}
