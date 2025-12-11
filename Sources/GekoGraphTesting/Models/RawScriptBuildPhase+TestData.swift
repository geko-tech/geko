import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoGraph

extension RawScriptBuildPhase {
    public static func test(
        name: String = "Test",
        script: String = "",
        showEnvVarsInLog: Bool = false,
        hashable: Bool = false
    ) -> RawScriptBuildPhase {
        RawScriptBuildPhase(name: name, script: script, showEnvVarsInLog: showEnvVarsInLog, hashable: hashable)
    }
}
