import AnyCodable
import Foundation

public struct CommandOutput: Encodable {
    public let exitCode: Int32
    public let errors: [CommandDiagnostic]
    public let warnings: [CommandDiagnostic]
    public let data: [String: AnyEncodable]?

    public init(
        exitCode: Int32,
        errors: [CommandDiagnostic],
        warnings: [CommandDiagnostic],
        data: [String: AnyEncodable]?
    ) {
        self.exitCode = exitCode
        self.errors = errors
        self.warnings = warnings
        self.data = data
    }
}

public struct CommandDiagnostic: Encodable {
    public let message: String
    public let type: String?

    public init(message: String, type: String? = nil) {
        self.message = message
        self.type = type
    }
}

public enum JSONOutputRenderer {
    public static func encode(_ output: CommandOutput) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(output)
    }

    public static func render(
        _ output: CommandOutput,
        to fileHandle: FileHandle = .standardOutput
    ) throws {
        var data = try encode(output)
        data.append(0x0A)
        try fileHandle.write(contentsOf: data)
    }
}
