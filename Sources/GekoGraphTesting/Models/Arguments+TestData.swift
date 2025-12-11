import Foundation
import struct ProjectDescription.AbsolutePath
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
