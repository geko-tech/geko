// swiftlint:disable force_try
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoGraph
@_exported import GekoKit
import XCTest
import GekoPlugin

@testable import GekoSupport
@testable import GekoSupportTesting
@testable import GekoCore

public enum Destination {
    case simulator, device
}

open class GekoAcceptanceTestCase: XCTestCase {
    public var xcodeprojPath: AbsolutePath!
    public var workspacePath: AbsolutePath!
    public var fixturePath: AbsolutePath!
    public var derivedDataPath: AbsolutePath { derivedDataDirectory.path }
    public var environment: MockEnvironment!
    public var sourceRootPath: AbsolutePath!

    private var derivedDataDirectory: TemporaryDirectory!
    private var fixtureTemporaryDirectory: TemporaryDirectory!

    override open func setUp() {
        super.setUp()

        DispatchQueue.once(token: "io.geko.test.logging") {
            LoggingSystem.bootstrap(AcceptanceTestCaseLogHandler.init)
        }

        derivedDataDirectory = try! TemporaryDirectory(removeTreeOnDeinit: true)
        fixtureTemporaryDirectory = try! TemporaryDirectory(removeTreeOnDeinit: true)

        let sourceURL = URL(fileURLWithPath: #file).pathComponents
            .prefix(while: { $0 != "Sources" }).joined(separator: "/").dropFirst()
        
        sourceRootPath = try! AbsolutePath(
            validating: String(sourceURL)
        )
        
        do {
            // Environment
            environment = try MockEnvironment()
            Environment.shared = environment
        } catch {
            XCTFail("Failed to setup environment")
        }

        // FileHandler
        let temporaryDirectory = try! TemporaryDirectory(removeTreeOnDeinit: true).path
        let fileHandler = MockFileHandler(temporaryDirectory: { temporaryDirectory })
        FileHandler.shared = fileHandler
    }

    override open func tearDown() async throws {
        xcodeprojPath = nil
        workspacePath = nil
        fixturePath = nil
        fixtureTemporaryDirectory = nil
        derivedDataDirectory = nil

        try await super.tearDown()
    }

    public func setUpFixture(_ fixture: GekoAcceptanceFixtures) throws {
        let fixturesPath = sourceRootPath
            .appending(component: "fixtures")

        fixturePath = fixtureTemporaryDirectory.path.appending(component: fixture.path)
        
        setenv(Constants.EnvironmentVariables.forceConfigCacheDirectory, fixturePath.appending(component: ".geko").pathString, 1)
        GekoPluginStorage.shared.register(gekoPlugins: [])
        CacheDirectoriesProvider.resetCachedEnvironments()
        ProjectDescriptionVersionProvider.shared.override(projectDescriptionVersion: Constants.projectDescriptionVersion)

        try FileHandler.shared.copy(
            from: fixturesPath.appending(component: fixture.path),
            to: fixturePath
        )
        
        let packageResolvedFile = fixturePath.appending(component: Constants.gekoDirectoryName).appending(component: Constants.DependenciesDirectory.packageResolvedName)
        
        try FileHandler.shared.write("""
            {
              "version": 2,
              "pins": []
            }
            """, path: packageResolvedFile, atomically: true)
    }
    
    public func setUpFixtureWorkspaceMapperPlugin(_ fixture: GekoAcceptanceFixtures) throws {
        try setUpFixture(fixture)
        
        let rootPackageResolvedPath = sourceRootPath.appending(component: "Package.resolved")
        guard let projectDescriptionVersion = try ProjectDescriptionBranchVersionParser().parse(packageResolvedPath: rootPackageResolvedPath) else {
            fatalError("Couldn't get the ProjectDescription version from Package.resolved")
        }
        
        let fixturePackagePath = fixturePath.appending(component: "Package.swift")
        var content = try FileHandler.shared.readTextFile(fixturePackagePath)
        
        content = content.replacingOccurrences(of: "<branch_version>", with: projectDescriptionVersion)
        
        try FileHandler.shared.write(content, path: fixturePackagePath, atomically: true)

        ProjectDescriptionVersionProvider.shared.override(projectDescriptionVersion: projectDescriptionVersion)
    }

    public func run(_ command: (some AsyncParsableCommand).Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--path", fixturePath.pathString,
        ]

        var parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: RunCommand.Type, _ arguments: String...) async throws {
        try await run(command, arguments)
    }

    public func run(_ command: RunCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = [
            "--path", fixturePath.pathString,
        ] + arguments

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: EditCommand.Type, _ arguments: String...) async throws {
        try await run(command, arguments)
    }

    public func run(_ command: EditCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--path", fixturePath.pathString,
            "--no-open",
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()

        xcodeprojPath = try FileHandler.shared.contentsOfDirectory(fixturePath.appending(components: [".geko", "GekoProject"]))
            .first(where: { $0.basename == "Manifests.xcodeproj" })
        workspacePath = try FileHandler.shared.contentsOfDirectory(fixturePath.appending(components: [".geko", "GekoProject"]))
            .first(where: { $0.basename == "Manifests.xcworkspace" })
    }

    public func run(_ command: MigrationTargetsByDependenciesCommand.Type, _ arguments: String...) throws {
        try run(command, arguments)
    }

    public func run(_ command: MigrationTargetsByDependenciesCommand.Type, _ arguments: [String] = []) throws {
        let parsedCommand = try command.parse(arguments)
        try parsedCommand.run()
    }

    public func run(_ command: TestCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--derived-data-path", derivedDataPath.pathString,
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: BuildCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--derived-data-path", derivedDataPath.pathString,
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: BuildCommand.Type, _ arguments: String...) async throws {
        try await run(command, arguments)
    }

    public func run(_ command: GenerateCommand.Type, arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--no-open",
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()

        xcodeprojPath = try FileHandler.shared.contentsOfDirectory(fixturePath)
            .first(where: { $0.extension == "xcodeproj" })
        workspacePath = try FileHandler.shared.contentsOfDirectory(fixturePath)
            .first(where: { $0.extension == "xcworkspace" })
    }

    public func run(_ command: (some AsyncParsableCommand).Type, _ arguments: String...) async throws {
        try await run(command, Array(arguments))
    }

    public func run(_ command: (some ParsableCommand).Type, _ arguments: [String] = []) throws {
        if String(describing: command) == "InitCommand" {
            fixturePath = fixtureTemporaryDirectory.path.appending(
                component: arguments[arguments.firstIndex(where: { $0 == "--name" })! + 1]
            )
        }
        var parsedCommand = try command.parseAsRoot(
            arguments +
                ["--path", fixturePath.pathString]
        )
        try parsedCommand.run()
    }

    public func run(_ command: (some ParsableCommand).Type, _ arguments: String...) throws {
        try run(command, Array(arguments))
    }

    public func addEmptyLine(to file: String) throws {
        let filePath = try fixturePath.appending(RelativePath(validating: file))
        var contents = try FileHandler.shared.readTextFile(filePath)
        contents += "\n"
        try FileHandler.shared.write(contents, path: filePath, atomically: true)
    }
}

// swiftlint:enable force_try
