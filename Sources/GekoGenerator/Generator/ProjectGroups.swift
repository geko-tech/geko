import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

enum ProjectGroupsError: FatalError, Equatable {
    case missingGroup(String)

    var description: String {
        switch self {
        case let .missingGroup(group):
            return "Couldn't find group: \(group)"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingGroup:
            return .bug
        }
    }
}

extension ProjectGroup {
    var name: String {
        switch self {
        case let .group(name):
            name
        case let .groupReference(name, _):
            name
        }
    }
}

class ProjectGroups {
    // MARK: - Attributes

    @SortedPBXGroup var sortedMain: PBXGroup
    let products: PBXGroup
    let frameworks: PBXGroup

    private let pbxproj: PBXProj
    private let projectGroups: [String: PBXGroup]

    // MARK: - Init

    private init(
        main: PBXGroup,
        projectGroups: [(name: String, group: PBXGroup)],
        products: PBXGroup,
        frameworks: PBXGroup,
        pbxproj: PBXProj
    ) {
        sortedMain = main
        self.projectGroups = Dictionary(uniqueKeysWithValues: projectGroups)
        self.products = products
        self.frameworks = frameworks
        self.pbxproj = pbxproj
    }

    func targetFrameworks(target: String) throws -> PBXGroup {
        if let group = frameworks.group(named: target) {
            return group
        } else {
            return try frameworks.addGroup(named: target, options: .withoutFolder).last!
        }
    }

    func projectGroup(named name: String) throws -> PBXGroup {
        guard let group = projectGroups[name] else {
            throw ProjectGroupsError.missingGroup(name)
        }
        return group
    }

    static func generate(
        project: Project,
        pbxproj: PBXProj
    ) -> ProjectGroups {
        /// Main
        let projectRelativePath = project.sourceRootPath.relative(to: project.xcodeProjPath.parentDirectory).pathString
        let textSettings = project.options.textSettings
        let mainGroup = PBXGroup(
            children: [],
            sourceTree: .group,
            path: (projectRelativePath != ".") ? projectRelativePath : nil,
            wrapsLines: textSettings.wrapsLines,
            usesTabs: textSettings.usesTabs,
            indentWidth: textSettings.indentWidth,
            tabWidth: textSettings.tabWidth
        )
        pbxproj.add(object: mainGroup)

        /// Project & Target Groups
        let groups = [project.filesGroup] + project.targets.map(\.filesGroup)
        let projectGroupNames = groups.map { $0.name }
        let groupsToCreate = OrderedSet(projectGroupNames)
        var projectGroups = [(name: String, group: PBXGroup)]()
        for groupName in groupsToCreate {
            let group = groups.first(where: { $0.name == groupName })! // swiftlint:disable:this force_unwrapping
            
            let projectGroup: PBXGroup
            switch group {
            case let .group(name: name):
                projectGroup = PBXGroup(children: [], sourceTree: .group, name: name)
            case let .groupReference(name: name, path: path):
                projectGroup = PBXGroup(children: [], sourceTree: .group, name: name, path: path.pathString)
            }
            
            pbxproj.add(object: projectGroup)
            mainGroup.children.append(projectGroup)
            projectGroups.append((groupName, projectGroup))
        }
        
        /// SDSKs & Pre-compiled frameworks
        let frameworksGroup = PBXGroup(children: [], sourceTree: .group, name: "Frameworks")
        pbxproj.add(object: frameworksGroup)
        mainGroup.children.append(frameworksGroup)

        /// Products
        let productsGroup = PBXGroup(children: [], sourceTree: .group, name: "Products")
        pbxproj.add(object: productsGroup)
        mainGroup.children.append(productsGroup)

        return ProjectGroups(
            main: mainGroup,
            projectGroups: projectGroups,
            products: productsGroup,
            frameworks: frameworksGroup,
            pbxproj: pbxproj
        )
    }
}
