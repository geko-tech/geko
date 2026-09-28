import ProjectDescription
import GekoLoader
import GekoSupport

extension TestPlan {

    func resolvePath(generatorPaths: GeneratorPaths) throws -> AbsolutePath {
        if let path = path {
            try generatorPaths.resolve(path: path).appending(component: name)
        } else {
            generatorPaths.manifestDirectory
                .appending(components: [
                    Constants.DerivedDirectory.name,
                    Constants.DerivedDirectory.testPlans,
                    name
                ])
        }
    }
}
