import Foundation
import ProjectDescription

extension Project: @retroactive CustomStringConvertible, CustomDebugStringConvertible {
    /// Initializes the project with its attributes.
    ///
    /// - Parameters:
    ///   - path: Path to the folder that contains the project manifest.
    ///   - sourceRootPath: Path to the directory where the Xcode project will be generated.
    ///   - xcodeProjPath: Path to the Xcode project that will be generated.
    ///   - name: Project name.
    ///   - organizationName: Organization name.
    ///   - defaultKnownRegions: Default known regions.
    ///   - developmentRegion: Development region.
    ///   - options: Additional project options.
    ///   - settings: The settings to apply at the project level
    ///   - filesGroup: The root group to place project files within
    ///   - targets: The project targets
    ///                      *(Those won't be included in any build phases)*
    ///   - schemes: Project schemes.
    ///   - ideTemplateMacros: IDE template macros that represent content of IDETemplateMacros.plist.
    ///   - additionalFiles: The additional files to include in the project
    ///   - lastUpgradeCheck: The version in which a check happened related to recommended settings after updating Xcode.
    ///   - isExternal: Indicates whether the project is imported through `Dependencies.swift`.
    public init(
        path: AbsolutePath,
        sourceRootPath: AbsolutePath,
        xcodeProjPath: AbsolutePath,
        name: String,
        organizationName: String?,
        options: Options,
        settings: Settings,
        filesGroup: ProjectGroup,
        targets: [Target],
        schemes: [Scheme],
        ideTemplateMacros: FileHeaderTemplate?,
        additionalFiles: [FileElement],
        lastUpgradeCheck: Version?,
        isExternal: Bool,
        projectType: ProjectType,
        podspecPath: AbsolutePath? = nil
    ) {
        self.init(
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            targets: targets,
            schemes: schemes,
            fileHeaderTemplate: ideTemplateMacros,
            additionalFiles: additionalFiles
        )

        self.path = path
        self.sourceRootPath = sourceRootPath
        self.xcodeProjPath = xcodeProjPath
        self.podspecPath = podspecPath
        self.lastUpgradeCheck = lastUpgradeCheck
        self.isExternal = isExternal
        self.projectType = projectType
        self.filesGroup = filesGroup
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        name
    }

    // MARK: - CustomDebugStringConvertible

    public var debugDescription: String {
        name
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    // MARK: - Public

    /// Returns a copy of the project with the given targets set.
    /// - Parameter targets: Targets to be set to the copy.
    public func with(targets: [Target]) -> Project {
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
            ideTemplateMacros: fileHeaderTemplate,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            projectType: projectType,
            podspecPath: podspecPath
        )
    }

    /// Returns a copy of the project with the given schemes set.
    /// - Parameter schemes: Schemes to be set to the copy.
    public func with(schemes: [Scheme]) -> Project {
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
            ideTemplateMacros: fileHeaderTemplate,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            projectType: projectType,
            podspecPath: podspecPath
        )
    }

    /// Returns the name of the default configuration.
    public var defaultDebugBuildConfigurationName: String {
        let debugConfiguration = settings.defaultDebugBuildConfiguration()
        let buildConfiguration = debugConfiguration ?? settings.configurations.keys.first
        return buildConfiguration?.name ?? BuildConfiguration.debug.name
    }
}
