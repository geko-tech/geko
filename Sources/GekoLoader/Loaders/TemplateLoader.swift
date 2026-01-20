import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol TemplateLoading {
    /// Load `GekoScaffold.Template` at given `path`
    /// - Parameters:
    ///     - path: Path of template manifest file `name_of_template.swift`
    /// - Returns: Loaded `GekoScaffold.Template`
    func loadTemplate(at path: AbsolutePath) throws -> Template
}

public class TemplateLoader: TemplateLoading {
    private let manifestLoader: ManifestLoading

    /// Default constructor.
    public convenience init() {
        self.init(manifestLoader: CompiledManifestLoader())
    }

    init(manifestLoader: ManifestLoading) {
        self.manifestLoader = manifestLoader
    }

    public func loadTemplate(at path: AbsolutePath) throws -> Template {
        let template = try manifestLoader.loadTemplate(at: path)
        let generatorPaths = GeneratorPaths(manifestDirectory: path)
        return try Template.from(
            manifest: template,
            generatorPaths: generatorPaths
        )
    }
}

extension Template {
    static func from(manifest: ProjectDescription.Template, generatorPaths: GeneratorPaths) throws -> Template {
        let attributes = try manifest.attributes.map(Template.Attribute.from)
        let items = try manifest.items.map { Item(
            path: try RelativePath(validating: $0.path).pathString,
            contents: try Template.Contents.from(
                manifest: $0.contents,
                generatorPaths: generatorPaths
            )
        ) }
        return Template(
            description: manifest.description,
            attributes: attributes,
            items: items
        )
    }
}

extension Template.Attribute {
    static func from(manifest: ProjectDescription.Template.Attribute) throws -> Template.Attribute {
        switch manifest {
        case let .required(name):
            return .required(name)
        case let .optional(name, default: defaultValue):
            return .optional(name, default: defaultValue)
        }
    }
}

extension Template.Contents {
    static func from(
        manifest: ProjectDescription.Template.Contents,
        generatorPaths: GeneratorPaths
    ) throws -> Template.Contents {
        switch manifest {
        case let .string(contents):
            return .string(contents)
        case let .file(templatePath):
            return .file(try generatorPaths.resolve(path: templatePath))
        case let .directory(sourcePath):
            return .directory(try generatorPaths.resolve(path: sourcePath))
        }
    }
}
