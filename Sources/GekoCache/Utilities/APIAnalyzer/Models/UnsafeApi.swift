import Foundation

public enum UnsafeApiReason: String, CaseIterable, Codable {
    case inferredType
    case macro
    case spi
}

public struct UnsafeApiDiagnostic: Codable {
    public let file: String
    public let line: Int
    public let column: Int
    public let reason: UnsafeApiReason
    public let declaration: String
}

public struct UnsafeApiDiagnosticsReport: Codable {
    public let diagnostics: [UnsafeApiDiagnostic]

    public init(diagnostics: [UnsafeApiDiagnostic]) {
        self.diagnostics = diagnostics
    }
}
