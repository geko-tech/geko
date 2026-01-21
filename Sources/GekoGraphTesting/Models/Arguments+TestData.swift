import Foundation
import ProjectDescription
@testable import GekoGraph

extension Arguments {
    public static func test(
        environmentVariables: [String: EnvironmentVariable] = [:],
        launchArguments: [LaunchArgument] = []
    ) -> Arguments {
        Arguments(
            environmentVariables: environmentVariables,
            launchArguments: launchArguments
        )
    }
}
