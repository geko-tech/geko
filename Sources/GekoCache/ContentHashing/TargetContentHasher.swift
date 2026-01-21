import AnyCodable
import Foundation
import GekoAnalytics
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public struct TargetContentHash {
    public let target: GraphTarget
    public let hash: String
    public let context: TargetContentHashContext
}

public struct TargetContentHashContext {
    public let name: String
    public let product: String
    public let productName: String
    public let bundleId: String?
    public let buildableFoldersHash: String
    public let buildableFoldersHashInfo: [String: String]
    public let sourcesHash: String
    public let sourcesHashInfo: [String: String]
    public let resourcesHash: String
    public let resourcesHashInfo: [String: String]
    public let copyFilesHash: String
    public let copyFilesHashInfo: [String: AnyCodable]
    public let coreDataModelsHash: String
    public let coreDataModelHashInfo: [String: AnyCodable]
    public let targetScriptsHash: String
    public let targetScriptsHashInfo: [String: AnyCodable]
    public let environmentHash: String
    public let environmentHashInfo: [String: EnvironmentVariable]
    public let headersHash: String?
    public let headersHashInfo: [String: String]?
    public let deploymentTargetHash: String
    public let deploymentTargetHashInfo: String
    public let infoPlistHash: String?
    public let entitlementsHash: String?
    public let settingsHash: String?
    public let settings: Settings?
    public let architecture: String?
    public let destinations: [String]
    public let additionalStrings: [String]
}

public protocol TargetContentHashing {
    func contentHash(
        for target: GraphTarget,
        cacheProfile: ProjectDescription.Cache.Profile,
        additionalStrings: [String]
    ) throws -> TargetContentHash
}

/// `TargetContentHasher`
/// is responsible for computing a unique hash that identifies a target
public final class TargetContentHasher: TargetContentHashing {
    private let contentHasher: ContentHashing
    private let buildableFoldersContentHasher: BuildableFoldersContentHashing
    private let coreDataModelsContentHasher: CoreDataModelsContentHashing
    private let sourceFilesContentHasher: SourceFilesContentHashing
    private let targetScriptsContentHasher: TargetScriptsContentHashing
    private let resourcesContentHasher: ResourcesContentHashing
    private let copyFilesContentHasher: CopyFilesContentHashing
    private let headersContentHasher: HeadersContentHashing
    private let deploymentTargetContentHasher: DeploymentTargetsContentHashing
    private let plistContentHasher: PlistContentHashing
    private let settingsContentHasher: SettingsContentHashing
    private let analytcisHandler: GekoAnalyticsStoreHandling

    // MARK: - Init

    public convenience init(contentHasher: ContentHashing) {
        self.init(
            contentHasher: contentHasher,
            buildableFoldersContentHasher: BuildableFoldersContentHasher(contentHasher: contentHasher),
            sourceFilesContentHasher: SourceFilesContentHasher(contentHasher: contentHasher),
            targetScriptsContentHasher: TargetScriptsContentHasher(contentHasher: contentHasher),
            coreDataModelsContentHasher: CoreDataModelsContentHasher(contentHasher: contentHasher),
            resourcesContentHasher: ResourcesContentHasher(contentHasher: contentHasher),
            copyFilesContentHasher: CopyFilesContentHasher(contentHasher: contentHasher),
            headersContentHasher: HeadersContentHasher(contentHasher: contentHasher),
            deploymentTargetContentHasher: DeploymentTargetsContentHasher(contentHasher: contentHasher),
            plistContentHasher: PlistContentHasher(contentHasher: contentHasher),
            settingsContentHasher: SettingsContentHasher(contentHasher: contentHasher),
            analytcisHandler: GekoAnalyticsStoreHandler()
        )
    }

    public init(
        contentHasher: ContentHashing,
        buildableFoldersContentHasher: BuildableFoldersContentHashing,
        sourceFilesContentHasher: SourceFilesContentHashing,
        targetScriptsContentHasher: TargetScriptsContentHashing,
        coreDataModelsContentHasher: CoreDataModelsContentHashing,
        resourcesContentHasher: ResourcesContentHashing,
        copyFilesContentHasher: CopyFilesContentHashing,
        headersContentHasher: HeadersContentHashing,
        deploymentTargetContentHasher: DeploymentTargetsContentHashing,
        plistContentHasher: PlistContentHashing,
        settingsContentHasher: SettingsContentHashing,
        analytcisHandler: GekoAnalyticsStoreHandling
    ) {
        self.contentHasher = contentHasher
        self.buildableFoldersContentHasher = buildableFoldersContentHasher
        self.sourceFilesContentHasher = sourceFilesContentHasher
        self.coreDataModelsContentHasher = coreDataModelsContentHasher
        self.targetScriptsContentHasher = targetScriptsContentHasher
        self.resourcesContentHasher = resourcesContentHasher
        self.copyFilesContentHasher = copyFilesContentHasher
        self.headersContentHasher = headersContentHasher
        self.deploymentTargetContentHasher = deploymentTargetContentHasher
        self.plistContentHasher = plistContentHasher
        self.settingsContentHasher = settingsContentHasher
        self.analytcisHandler = analytcisHandler
    }

    // MARK: - TargetContentHashing

    // swiftlint:disable:next function_body_length
    public func contentHash(
        for graphTarget: GraphTarget,
        cacheProfile: ProjectDescription.Cache.Profile,
        additionalStrings: [String] = []
    ) throws -> TargetContentHash {
        let name = graphTarget.target.name
        let product = graphTarget.target.product.rawValue
        let bundleId = graphTarget.target.bundleId
        let productName = graphTarget.target.productName
        let (buildableFoldersHash, buildableFoldersHashInfo, folderSourcesHashInfo) = try buildableFoldersContentHasher.hash(buildableFolders: graphTarget.target.buildableFolders)
        var (sourcesHash, sourcesHashInfo) = try sourceFilesContentHasher.hash(sources: graphTarget.target.sources)
        sourcesHashInfo.merge(folderSourcesHashInfo) { $1 }
        let (resourcesHash, resourcesHashInfo) = try resourcesContentHasher.hash(resources: graphTarget.target.resources)
        let (copyFilesHash, copyFileHashInfo) = try copyFilesContentHasher.hash(copyFiles: graphTarget.target.copyFiles)
        let (coreDataModelHash, coreDataModelHashInfo) = try coreDataModelsContentHasher.hash(coreDataModels: graphTarget.target.coreDataModels)
        let (targetScriptsHash, targetScriptsHashInfo) = try targetScriptsContentHasher.hash(
            targetScripts: graphTarget.target.scripts,
            sourceRootPath: graphTarget.project.sourceRootPath,
            cacheProfile: cacheProfile
        )

        let environmentHash = try contentHasher.hash(graphTarget.target.environmentVariables.mapValues(\.value))
        let environmentHashInfo = graphTarget.target.environmentVariables
        var stringsToHash = [
            name,
            product,
            bundleId ?? "",
            productName,
            buildableFoldersHash,
            sourcesHash,
            resourcesHash,
            copyFilesHash,
            coreDataModelHash,
            targetScriptsHash,
            environmentHash,
        ]

        let destinations = graphTarget.target.destinations.map(\.rawValue).sorted()
        stringsToHash.append(contentsOf: destinations)

        var headersHashs: String?
        var headersHashInfo: [String: String]?
        if let headers = graphTarget.target.headers {
            let (hash, info) = try headersContentHasher.hash(headers: headers)
            headersHashs = hash
            headersHashInfo = info
            stringsToHash.append(hash)
        }

        let (deploymentTargetHash, deploymentTargetHashInfo) =
            try deploymentTargetContentHasher
            .hash(deploymentTargets: graphTarget.target.deploymentTargets)
        stringsToHash.append(deploymentTargetHash)

        var infoPlistHash: String?
        if let infoPlist = graphTarget.target.infoPlist {
            let hash = try plistContentHasher.hash(plist: .infoPlist(infoPlist))
            infoPlistHash = hash
            stringsToHash.append(hash)
        }
        var entitlementsHash: String?
        if let entitlements = graphTarget.target.entitlements {
            let hash = try plistContentHasher.hash(plist: .entitlements(entitlements))
            entitlementsHash = hash
            stringsToHash.append(hash)
        }
        var settingsHash: String?
        if let settings = graphTarget.target.settings {
            let hash = try settingsContentHasher.hash(
                settings: settings,
                cacheProfile: cacheProfile
            )
            settingsHash = hash
            stringsToHash.append(hash)
        }
        stringsToHash += additionalStrings

        var architecture: String?
        if graphTarget.target.deploymentTargets.macOS != nil {
            architecture = DeveloperEnvironment.shared.architecture.rawValue
            stringsToHash.append(DeveloperEnvironment.shared.architecture.rawValue)
        }

        let targetHash = try contentHasher.hash(stringsToHash)
        let context = TargetContentHashContext(
            name: name,
            product: product,
            productName: productName,
            bundleId: bundleId,
            buildableFoldersHash: buildableFoldersHash,
            buildableFoldersHashInfo: buildableFoldersHashInfo,
            sourcesHash: sourcesHash,
            sourcesHashInfo: sourcesHashInfo,
            resourcesHash: resourcesHash,
            resourcesHashInfo: resourcesHashInfo,
            copyFilesHash: copyFilesHash,
            copyFilesHashInfo: copyFileHashInfo,
            coreDataModelsHash: coreDataModelHash,
            coreDataModelHashInfo: coreDataModelHashInfo,
            targetScriptsHash: targetScriptsHash,
            targetScriptsHashInfo: targetScriptsHashInfo,
            environmentHash: environmentHash,
            environmentHashInfo: environmentHashInfo,
            headersHash: headersHashs,
            headersHashInfo: headersHashInfo,
            deploymentTargetHash: deploymentTargetHash,
            deploymentTargetHashInfo: deploymentTargetHashInfo,
            infoPlistHash: infoPlistHash,
            entitlementsHash: entitlementsHash,
            settingsHash: settingsHash,
            settings: graphTarget.target.settings,
            architecture: architecture,
            destinations: destinations,
            additionalStrings: additionalStrings
        )

        return TargetContentHash(
            target: graphTarget,
            hash: targetHash,
            context: context
        )
    }
}
