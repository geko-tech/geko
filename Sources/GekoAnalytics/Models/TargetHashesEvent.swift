import AnyCodable
import Foundation
import GekoGraph
import ProjectDescription

public struct TargetHashesEvent: Codable, Equatable {
    public let name: String
    public let product: String
    public let productName: String
    public let bundleId: String?
    public let resultHash: String
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
    public let dependenciesHash: String
    public let dependenciesHashInfo: [String: String]
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
    public let date: Date

    public init(
        name: String,
        product: String,
        productName: String,
        bundleId: String?,
        resultHash: String,
        sourcesHash: String,
        sourcesHashInfo: [String: String],
        resourcesHash: String,
        resourcesHashInfo: [String: String],
        copyFilesHash: String,
        copyFilesHashInfo: [String: AnyCodable],
        coreDataModelsHash: String,
        coreDataModelHashInfo: [String: AnyCodable],
        targetScriptsHash: String,
        targetScriptsHashInfo: [String: AnyCodable],
        dependenciesHash: String,
        dependenciesHashInfo: [String: String],
        environmentHash: String,
        environmentHashInfo: [String: EnvironmentVariable],
        headersHash: String?,
        headersHashInfo: [String: String]?,
        deploymentTargetHash: String,
        deploymentTargetHashInfo: String,
        infoPlistHash: String?,
        entitlementsHash: String?,
        settingsHash: String?,
        settings: Settings?,
        architecture: String?,
        destinations: [String],
        additionalStrings: [String],
        date: Date
    ) {
        self.name = name
        self.product = product
        self.productName = productName
        self.bundleId = bundleId
        self.resultHash = resultHash
        self.sourcesHash = sourcesHash
        self.sourcesHashInfo = sourcesHashInfo
        self.resourcesHash = resourcesHash
        self.resourcesHashInfo = resourcesHashInfo
        self.copyFilesHash = copyFilesHash
        self.copyFilesHashInfo = copyFilesHashInfo
        self.coreDataModelsHash = coreDataModelsHash
        self.coreDataModelHashInfo = coreDataModelHashInfo
        self.targetScriptsHash = targetScriptsHash
        self.targetScriptsHashInfo = targetScriptsHashInfo
        self.dependenciesHash = dependenciesHash
        self.dependenciesHashInfo = dependenciesHashInfo
        self.environmentHash = environmentHash
        self.environmentHashInfo = environmentHashInfo
        self.headersHash = headersHash
        self.headersHashInfo = headersHashInfo
        self.deploymentTargetHash = deploymentTargetHash
        self.deploymentTargetHashInfo = deploymentTargetHashInfo
        self.infoPlistHash = infoPlistHash
        self.entitlementsHash = entitlementsHash
        self.settingsHash = settingsHash
        self.settings = settings
        self.architecture = architecture
        self.destinations = destinations
        self.additionalStrings = additionalStrings
        self.date = date
    }
}
