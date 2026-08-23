import Foundation

public enum FileAnalyzeClassification: String, Codable {
    case noPublicApi
    case safe
    case unsafe
}

public struct FileAnalyzeReport: Codable {
    public let path: String
    public let classification: FileAnalyzeClassification
    public let unsafeReasons: Set<UnsafeApiReason>
    public let diagnostics: [UnsafeApiDiagnostic]
}

struct ModuleReport {
    public let name: String
    public let swiftFiles: Int
    public let apiFiles: Int
    public let unsafeApiFiles: Int
    public let unsafeApiRatio: Double
    public let containsUnsafeAPI: Bool
    public let files: [FileAnalyzeReport]
}

public struct APIAnalyzeSummary {
    public let modules: Int
    public let modulesWithSwiftSources: Int
    public let unsafeModules: Int
    public let unsafeModuleRatio: Double
    public let apiFiles: Int
    public let unsafeApiFiles: Int
    public let unsafeApiRatio: Double
    public let unsafeReasons: [UnsafeApiReason: Int]
}

public struct APIAnalyzeReport {
    public let summary: APIAnalyzeSummary
    public let diagnostics: [UnsafeApiDiagnostic]
}
