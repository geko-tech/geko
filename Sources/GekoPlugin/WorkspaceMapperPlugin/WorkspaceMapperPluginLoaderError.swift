import Foundation
import GekoSupport
import ProjectDescription

enum WorkspaceMapperPluginLoaderError: FatalError, Equatable {
    case pluginNotFound(pluginName: String)
    case errorLoadingPlugin(pluginName: String, mapperPath: String, dlopenErrorText: String)
    case errorLoadingSymbol(symbolName: String, pluginName: String, path: String)
    case errorPluginMagicNumber(expected: Int, got: Int)
    case differentVersionsOfProjectDescription(pluginName: String, pluginProjectDescriptionVersion: String, projectDescriptionVersion: String)
    case gekoProjectDescriptionError(projectDescriptionVersion: String)
    case pluginProjectDescriptionError(pluginName: String, pluginProjectDescriptionVersion: String)
    case pluginProjectDescriptionVersionMismatch(pluginName: String, pluginProjectDescriptionVersion: String, projectDescriptionVersion: String, projectDescriptionVersionParsed: Version)
    case pluginProjectDescriptionVersionGreaterThanGekoSupported(pluginName: String, pluginProjectDescriptionVersion: String, projectDescriptionVersion: String)

    var description: String {
        switch self {
        case let .pluginNotFound(pluginName):
            "The plugin was not found or plugin may not be supported on the current OS: \(pluginName)."
        case let .errorLoadingPlugin(pluginName, mapperPath, dlopenErrorText):
            "Error loading plugin \(pluginName) at path \(mapperPath). Error: \(dlopenErrorText)."
        case let .errorLoadingSymbol(symbolName, pluginName, path):
            "Error loading symbol \(symbolName) from plugin \(pluginName) at path \(path)"
        case let .errorPluginMagicNumber(expected, got):
            "The plugin's MagicNumber doesn't match. Expected - \(expected), got - \(got)."
        case let .differentVersionsOfProjectDescription(pluginName, pluginProjectDescriptionVersion, projectDescriptionVersion):
            "The '\(pluginName)' plugin and Geko have different versions of ProjectDescription ('\(pluginName)' uses version '\(pluginProjectDescriptionVersion)', while Geko uses version '\(projectDescriptionVersion)'), which may cause issues when using mappers."
        case let .gekoProjectDescriptionError(projectDescriptionVersion):
            "Failed to retrieve the version of ProjectDescription '\(projectDescriptionVersion)' from Geko"
        case let .pluginProjectDescriptionError(pluginName, pluginProjectDescriptionVersion):
            "Failed to retrieve the version of ProjectDescription '\(pluginProjectDescriptionVersion)' from plugin '\(pluginName)'. Example version - 'release/x.x.x'"
        case let .pluginProjectDescriptionVersionMismatch(pluginName, pluginProjectDescriptionVersion, projectDescriptionVersion, projectDescriptionVersionParsed):
            "The Major or Minor version of ProjectDescription '\(pluginProjectDescriptionVersion)' in plugin '\(pluginName)' does not match the Major or Minor version of ProjectDescription '\(projectDescriptionVersion)' in Geko. ABI stability is only guaranteed for Patch versions. Please update the ProjectDescription version in the plugins to 'release/\(projectDescriptionVersionParsed.major).\(projectDescriptionVersionParsed.minor).x'."
        case let .pluginProjectDescriptionVersionGreaterThanGekoSupported(pluginName, pluginProjectDescriptionVersion, projectDescriptionVersion):
            "The ProjectDescription patch version '\(pluginProjectDescriptionVersion)' in plugin '\(pluginName)' cannot be greater than the ProjectDescription Geko version '\(projectDescriptionVersion)'."
        }
    }

    var type: ErrorType {
        switch self {
        case .pluginNotFound, .errorLoadingPlugin, .errorLoadingSymbol, .errorPluginMagicNumber, .differentVersionsOfProjectDescription, .gekoProjectDescriptionError, .pluginProjectDescriptionError, .pluginProjectDescriptionVersionMismatch, .pluginProjectDescriptionVersionGreaterThanGekoSupported:
            .abort
        }
    }
}
