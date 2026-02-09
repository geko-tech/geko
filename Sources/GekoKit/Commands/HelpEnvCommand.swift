import ArgumentParser
import GekoSupport

struct HelpEnvCommand: AsyncParsableCommand {
    static func envHelp(for variable: Constants.EnvironmentVariables) -> String {
        switch variable {
        case .verbose:
            return "Enable verbose logging. Defaults to 'false'."
        case .colouredOutput:
            return "Enable colored output. Defaults to 'true'."
        case .versionsDirectory:
            return "Customize versions directory for autoupdate. Defaults to `~/.geko/Versions`"
        case .forceConfigCacheDirectory:
            return "Customize cache directory. Defaults to `~/.geko/Cache`"
        case .detailedLog:
            return "Enable detailed logging. Deafults to 'false'."
        case .osLog:
            return "Enable OSLog logger. Defaults to 'false'."

        case .inspectSourceRef:
            return "Source git ref for inspect command in diff mode. When searching for changes geko will compare \(Constants.EnvironmentVariables.inspectSourceRef.rawValue) and \(Constants.EnvironmentVariables.inspectTargetRef.rawValue) refs. Default value is not provided but required in diff mode."
        case .inspectTargetRef:
            return "Target git ref for inpsect command in diff mode. Defaults to 'HEAD'."

        case .cloudAccessKey:
            return "Access key of s3 cache storage. Leave empty when auth is not required."
        case .cloudSecretKey:
            return "Secret key of s3 cache storage. Leave empty when auth is not required."
        case .statsOutput:
            return "Enable analytics output. Defaults to 'true'. Analytics will be logged into file `.geko/Analytics/{date}/{command}.json`."
        case .cacheTargetHashesSave:
            return "Saves logs for each module during cache warmup."
        case .forceConfigLogDirectory:
            return "Allows to specify custom folder for build, hash, and analytics logs. Defaults to `.geko` directory in the project root."
        case .cocoapodsCacheDirectory:
            return "Customize cocoapods cache directory. Defaults to `~/Library/Caches/Geko`."
        case .cocoapodsRepoCacheDirectory:
            return "Customize cocoapods repository cache directory. Defaults to `~/.geko/CocoapodsRepoCache`."
        case .requestTimeout:
            return "Specify request timeout in seconds for cache requests. Defaults to `10`."
        case .swiftModuleCache:
            return "Enable swift module cache. Defaults to `false`. This variable has higher precedence than `.profile(options: .options(swiftModuleCacheEnabled:))` in `Config.swift`."
        case .forceBuildCacheDirectory:
            return "Customize cache build directory. Default value is not specified. This environment variable has higher precedence than `Cache(path:)` in `Config.swift`."
        }
    }

    static func buildEnvHelp() -> String {
        return Constants.EnvironmentVariables.allCases
                .map { "  \($0.rawValue)\n    \(envHelp(for: $0))\n" }
                .joined(separator: "\n")
    }

    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "help-env",
            abstract: "Display environment variables help",
            discussion: buildEnvHelp()
        )
    }
}
