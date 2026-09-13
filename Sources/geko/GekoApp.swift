import Foundation
import struct ProjectDescription.AbsolutePath
import GekoKit
import GekoLoader
import GekoSupport

@main
@_documentation(visibility: private)
private enum GekoApp {
    static func main() async throws {
        if CommandLine.topLevelArguments.contains("--verbose") {
            try? ProcessEnv.setVar(Constants.EnvironmentVariables.verbose.rawValue, value: "true")
        }
        if CommandLine.topLevelArguments.contains("--quiet") {
            try? ProcessEnv.setVar(Constants.EnvironmentVariables.quiet.rawValue, value: "true")
        }
        if CommandLine.topLevelArguments.contains("--structured") {
            try? ProcessEnv.setVar(Constants.EnvironmentVariables.structured.rawValue, value: "true")
        }
        if CommandLine.topLevelArguments.contains("--include-build-warnings") {
            try? ProcessEnv.setVar(Constants.EnvironmentVariables.includeBuildWarnings.rawValue, value: "true")
        }

        // bootstrap must be called before everything else
        GekoSupport.LogOutput.bootstrap()

        do {
            #if !DEBUG
            try await startCorrectVersion()
            #endif

            try GekoSupport.Environment.shared.bootstrap()
        } catch {
            GekoCommand.exit(with: error)
        }

        await GekoCommand.main()
    }
}
