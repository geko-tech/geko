import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph

@testable import GekoCore
@testable import GekoScaffold

public final class MockTemplateGenerator: TemplateGenerating {
    public var generateStub: ((Template, AbsolutePath, [String: String]) throws -> Void)?

    public func generate(template: Template, to destinationPath: AbsolutePath, attributes: [String: String]) throws {
        try generateStub?(template, destinationPath, attributes)
    }
}
