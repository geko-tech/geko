import Foundation
import GekoGraph
import ProjectDescription

@testable import GekoCore
@testable import GekoScaffold

public final class MockTemplateGenerator: TemplateGenerating {
    public var generateStub: ((Template, AbsolutePath, [String: String]) throws -> Void)?

    public func generate(template: Template, to destinationPath: AbsolutePath, attributes: [String: String]) throws {
        try generateStub?(template, destinationPath, attributes)
    }
}
