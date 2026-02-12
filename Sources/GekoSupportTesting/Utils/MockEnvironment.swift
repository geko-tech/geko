import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport
import XCTest

public class MockEnvironment: Environmenting {
    fileprivate let directory: TemporaryDirectory
    fileprivate var setupCallCount: UInt = 0
    fileprivate var setupErrorStub: Error?

    init() throws {
        directory = try TemporaryDirectory(removeTreeOnDeinit: true)
        try FileManager.default.createDirectory(
            at: versionsDirectory.url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    public var isVerbose: Bool = false
    public var shouldOutputBeColoured: Bool = false
    public var isStandardOutputInteractive: Bool = false
    public var gekoVariables: [String: String] = [:]
    public var gekoConfigVariables: [String: String] = [:]
    public var manifestLoadingVariables: [String: String] = [:]
    public var isStatsEnabled: Bool = true
    public var isGitHubActions: Bool = false
    public var impactAnalysisEnabled: Bool = false
    public var impactSourceRef: String? = nil
    public var impactTargetRef: String? = nil
    public var impactAnalysisDebug: Bool = false
    public var impactAnalysisSymlinksSupportEnabled: Bool = false
    public var impactAnalysisChangedTargets: [String] = []
    public var impactAnalysisChangedProducts: [String] = []
    public var inspectSourceRef: String? = nil
    public var inspectTargetRef: String? = nil
    public var targetHashesSaveEnabled: Bool = false
    public var swiftModuleCacheEnabled: Bool? = nil

    public var versionsDirectory: AbsolutePath {
        directory.path.appending(component: "Versions")
    }

    public var settingsPath: AbsolutePath {
        directory.path.appending(component: "settings.json")
    }

    public var requestTimeout: TimeInterval? {
        nil
    }

    func path(version: String) -> AbsolutePath {
        versionsDirectory.appending(component: version)
    }

    public func bootstrap() throws {}
}
