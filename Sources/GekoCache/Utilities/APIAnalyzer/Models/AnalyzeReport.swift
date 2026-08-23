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
