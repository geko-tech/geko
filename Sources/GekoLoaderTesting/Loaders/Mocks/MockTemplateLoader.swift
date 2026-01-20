import Foundation
import GekoGraph
import GekoLoader
import ProjectDescription

public final class MockTemplateLoader: TemplateLoading {
    public var loadTemplateStub: ((AbsolutePath) throws -> Template)?
    public func loadTemplate(at path: AbsolutePath) throws -> Template {
        try loadTemplateStub?(path) ?? Template(description: "", attributes: [], items: [])
    }
}
