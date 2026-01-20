import Foundation
import ProjectDescription
@testable import GekoGraph

extension Project {
    public static func test(
        path: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/Project"), // swiftlint:disable:this force_try
        sourceRootPath: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/Project"), // swiftlint:disable:this force_try
        // swiftlint:disable:next force_try
        xcodeProjPath: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/Project/Project.xcodeproj"),
        name: String = "Project",
        organizationName: String? = nil,
        options: Options = .test(automaticSchemesOptions: .disabled),
        settings: Settings = Settings.test(),
        filesGroup: ProjectGroup = .group(name: "Project"),
        targets: [Target] = [Target.test()],
        schemes: [Scheme] = [],
        ideTemplateMacros: FileHeaderTemplate? = nil,
        additionalFiles: [FileElement] = [],
        lastUpgradeCheck: Version? = nil,
        isExternal: Bool = false,
        projectType: ProjectType = .geko,
        podspecPath: AbsolutePath? = nil
    ) -> Project {
        Project(
            path: path,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath,
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            filesGroup: filesGroup,
            targets: targets,
            schemes: schemes,
            ideTemplateMacros: ideTemplateMacros,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            projectType: projectType,
            podspecPath: podspecPath
        )
    }

    public static func empty(
        path: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/test/"), // swiftlint:disable:this force_try
        sourceRootPath: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/test/"), // swiftlint:disable:this force_try
        xcodeProjPath: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/test/text.xcodeproj"), // swiftlint:disable:this force_try
        name: String = "Project",
        organizationName: String? = nil,
        options: Options = .test(automaticSchemesOptions: .disabled),
        settings: Settings = .default,
        filesGroup: ProjectGroup = .group(name: "Project"),
        targets: [Target] = [],
        schemes: [Scheme] = [],
        ideTemplateMacros: FileHeaderTemplate? = nil,
        additionalFiles: [FileElement] = [],
        lastUpgradeCheck: Version? = nil,
        isExternal: Bool = false,
        projectType: ProjectType = .geko,
        podspecPath: AbsolutePath? = nil
    ) -> Project {
        Project(
            path: path,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath,
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            filesGroup: filesGroup,
            targets: targets,
            schemes: schemes,
            ideTemplateMacros: ideTemplateMacros,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            projectType: .geko,
            podspecPath: podspecPath
        )
    }
}
