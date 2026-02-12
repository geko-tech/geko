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

        // bootstrap must be called before everything else
        GekoSupport.LogOutput.bootstrap()

        #if !DEBUG
        try await startCorrectVersion()
        #endif

        try GekoSupport.Environment.shared.bootstrap()

        await GekoCommand.main()
    }
}
