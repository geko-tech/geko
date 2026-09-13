import Foundation
import AnyCodable

public struct CommandOutput: Encodable {
    public let exitCode: Int32
    public let errors: [CommandDiagnostic]
    public let warnings: [CommandDiagnostic]
    public let data: [String: AnyCodable]?
    
    public init(exitCode: Int32, errors: [CommandDiagnostic], warnings: [CommandDiagnostic], data: [String: AnyCodable]?) {
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

public struct JSONOutputRender {
    public static func render(_ output: CommandOutput) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(output)
        guard let string = String(data: data, encoding: .utf8) else { return }
        
        print(string) // TODO 
    }
}
