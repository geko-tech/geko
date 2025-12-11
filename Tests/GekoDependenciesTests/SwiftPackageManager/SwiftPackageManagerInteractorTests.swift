import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
import Yams
@testable import GekoDependencies
@testable import GekoDependenciesTesting
@testable import GekoSupportTesting

final class SwiftPackageManagerInteractorTests: GekoUnitTestCase {
    private var subject: SwiftPackageManagerInteractor!
    private var swiftPackageManagerController: MockSwiftPackageManagerController!
    private var swiftPackageManagerGraphGenerator: MockSwiftPackageManagerGraphGenerator!

    override func setUp() {
        super.setUp()

        swiftPackageManagerController = MockSwiftPackageManagerController()
        swiftPackageManagerGraphGenerator = MockSwiftPackageManagerGraphGenerator()
        subject = SwiftPackageManagerInteractor(
            swiftPackageManagerController: swiftPackageManagerController,
            swiftPackageManagerGraphGenerator: swiftPackageManagerGraphGenerator
        )
    }

    override func tearDown() {
        subject = nil
        swiftPackageManagerController = nil

        super.tearDown()
    }

    func test_install_when_shouldNotBeUpdated() throws {
        // Given
        let rootPath = try TemporaryDirectory(removeTreeOnDeinit: true).path
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)
        let swiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        let swiftPackageManagerBuildDirectory = swiftPackageManagerDirectory.appending(component: ".build")
        let dependenciesFilePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return """
                {
                  "version": 2,
                  "pins": []
                }
                """.data(using: .utf8)!
            }
        }

        try fileHandler.touch(dependenciesFilePath)
        try fileHandler.touch(packageResolvedFilePath)
        try fileHandler.touch(workspaceStatePath)

        system.swiftVersionStub = { "5.6.0" }
        swiftPackageManagerController.resolveStub = { path, arguments, printOutput in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertTrue(printOutput)
            try self.simulateSPMOutput(at: path)
        }
        swiftPackageManagerController.setToolsVersionStub = { path, version in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(version, Version(5, 6, 0))
        }

        swiftPackageManagerGraphGenerator
            .generateStub =
            { path, automaticProductType, baseSettings, targetSettings, swiftToolsVersion, projectOptions, resolvedDependenciesVersions in
                XCTAssertEqual(path, swiftPackageManagerBuildDirectory)
                XCTAssertEqual(automaticProductType, [:])
                XCTAssertEqual(baseSettings, .default)
                XCTAssertEqual(targetSettings, [:])
                XCTAssertNil(swiftToolsVersion)
                XCTAssertEqual(projectOptions, [:])
                XCTAssertEqual(resolvedDependenciesVersions, [:]
                )
                return .test()
            }

        // When
        let dependenciesGraph = try subject.install(
            dependenciesDirectory: dependenciesDirectory,
            packageSettings: .test(baseSettings: .default),
            arguments: [],
            shouldUpdate: false,
            swiftToolsVersion: nil
        )

        // Then
        XCTAssertEqual(dependenciesGraph, .test())
        try XCTAssertDirectoryContentEqual(
            dependenciesDirectory,
            [
                Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            ]
        )
        try XCTAssertDirectoryContentEqual(
            rootPath,
            [
                "Dependencies",
                "Geko",
                Constants.DependenciesDirectory.packageResolvedName,
                "Package.swift"
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerDirectory,
            [
                ".build",
                "Package.swift",
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerBuildDirectory,
            [
                "manifest.db",
                "workspace-state.json",
                "artifacts",
                "checkouts",
                "repositories",
            ]
        )

        XCTAssertTrue(swiftPackageManagerController.invokedResolve)
        XCTAssertTrue(swiftPackageManagerController.invokedSetToolsVersion)
        XCTAssertFalse(swiftPackageManagerController.invokedUpdate)
    }

    func test_install_when_shouldNotBeUpdated_and_swiftToolsVersionPassed() throws {
        // Given
        let rootPath = try TemporaryDirectory(removeTreeOnDeinit: true).path
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)
        let swiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        let swiftPackageManagerBuildDirectory = swiftPackageManagerDirectory.appending(component: ".build")
        let packageResolvedFile = rootPath.appending(component: Constants.DependenciesDirectory.packageResolvedName)
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]
        
        let dependenciesFilePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return """
                {
                  "version": 2,
                  "pins": []
                }
                """.data(using: .utf8)!
            }
        }
        
        try fileHandler.touch(dependenciesFilePath)
        try fileHandler.touch(packageResolvedFile)
        try fileHandler.touch(workspaceStatePath)

        let swiftToolsVersion = Version(5, 3, 0)

        system.swiftVersionStub = { "5.6.0" }
        swiftPackageManagerController.resolveStub = { path, arguments, printOutput in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(arguments, stubbedPassthroughArguments)
            XCTAssertTrue(printOutput)
            try self.simulateSPMOutput(at: path)
        }
        swiftPackageManagerController.setToolsVersionStub = { path, version in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(version, swiftToolsVersion)
        }

        swiftPackageManagerGraphGenerator
            .generateStub = { path, automaticProductType, baseSettings, targetSettings, swiftVersion, projectOptions, resolvedDependenciesVersions in
                XCTAssertEqual(path, swiftPackageManagerBuildDirectory)
                XCTAssertEqual(automaticProductType, [:])
                XCTAssertEqual(baseSettings, .default)
                XCTAssertEqual(targetSettings, [:])
                XCTAssertEqual(swiftVersion, swiftToolsVersion)
                XCTAssertEqual(projectOptions, [:])
                XCTAssertEqual(resolvedDependenciesVersions, [:])
                return .test()
            }

        // When
        let dependenciesGraph = try subject.install(
            dependenciesDirectory: dependenciesDirectory,
            packageSettings: .test(baseSettings: .default),
            arguments: stubbedPassthroughArguments,
            shouldUpdate: false,
            swiftToolsVersion: swiftToolsVersion
        )

        // Then
        XCTAssertEqual(dependenciesGraph, .test())
        try XCTAssertDirectoryContentEqual(
            dependenciesDirectory,
            [
                Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            ]
        )
        try XCTAssertDirectoryContentEqual(
            rootPath,
            [
                "Dependencies",
                Constants.DependenciesDirectory.packageResolvedName,
                "Package.swift"
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerDirectory,
            [
                ".build",
                "Package.swift",
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerBuildDirectory,
            [
                "manifest.db",
                "workspace-state.json",
                "artifacts",
                "checkouts",
                "repositories",
            ]
        )

        XCTAssertTrue(swiftPackageManagerController.invokedResolve)
        XCTAssertTrue(swiftPackageManagerController.invokedSetToolsVersion)
        XCTAssertFalse(swiftPackageManagerController.invokedUpdate)
    }

    func test_install_when_shouldBeUpdated() throws {
        // Given
        let rootPath = try TemporaryDirectory(removeTreeOnDeinit: true).path
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)
        let lockfilesDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.lockfilesDirectoryName)
        let swiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        let swiftPackageManagerBuildDirectory = swiftPackageManagerDirectory.appending(component: ".build")
        let packageResolvedFile = lockfilesDirectory.appending(component: Constants.DependenciesDirectory.packageResolvedName)
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]
        
        let dependenciesFilePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return """
                {
                  "version": 2,
                  "pins": []
                }
                """.data(using: .utf8)!
            }
        }
        
        try fileHandler.touch(dependenciesFilePath)
        try fileHandler.touch(packageResolvedFile)
        try fileHandler.touch(workspaceStatePath)

        system.swiftVersionStub = { "5.6.0" }
        swiftPackageManagerController.updateStub = { path, arguments, printOutput in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(arguments, stubbedPassthroughArguments)
            XCTAssertTrue(printOutput)
            try self.simulateSPMOutput(at: path)
        }
        swiftPackageManagerController.setToolsVersionStub = { path, version in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(version, Version("5.6.0"))
        }

        swiftPackageManagerGraphGenerator
            .generateStub =
            { path, automaticProductType, baseSettings, targetSettings, swiftToolsVersion, configuration, resolvedDependenciesVersions in
                XCTAssertEqual(path, swiftPackageManagerBuildDirectory)
                XCTAssertEqual(automaticProductType, [:])
                XCTAssertEqual(baseSettings, .default)
                XCTAssertEqual(targetSettings, [:])
                XCTAssertNil(swiftToolsVersion)
                XCTAssertEqual(configuration, [:])
                XCTAssertEqual(resolvedDependenciesVersions, [:])
                return .test()
            }

        // When
        let dependenciesGraph = try subject.install(
            dependenciesDirectory: dependenciesDirectory,
            packageSettings: .test(baseSettings: .default),
            arguments: stubbedPassthroughArguments,
            shouldUpdate: true,
            swiftToolsVersion: nil
        )


        // Then
        XCTAssertEqual(dependenciesGraph, .test())
        try XCTAssertDirectoryContentEqual(
            dependenciesDirectory,
            [
                Constants.DependenciesDirectory.lockfilesDirectoryName,
                Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            ]
        )
        try XCTAssertDirectoryContentEqual(
            lockfilesDirectory,
            [
                Constants.DependenciesDirectory.packageResolvedName,
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerDirectory,
            [
                ".build",
                "Package.swift",
            ]
        )
        try XCTAssertDirectoryContentEqual(
            swiftPackageManagerBuildDirectory,
            [
                "manifest.db",
                "workspace-state.json",
                "artifacts",
                "checkouts",
                "repositories",
            ]
        )

        XCTAssertTrue(swiftPackageManagerController.invokedUpdate)
        XCTAssertTrue(swiftPackageManagerController.invokedSetToolsVersion)
        XCTAssertFalse(swiftPackageManagerController.invokedResolve)
    }
    
    func test_resolved_dependencies_versions_shouldBe() throws {
        // Given
        let rootPath = try TemporaryDirectory(removeTreeOnDeinit: true).path
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)
        let swiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        let swiftPackageManagerBuildDirectory = swiftPackageManagerDirectory.appending(component: ".build")
        let packageResolvedFile = rootPath.appending(component: Constants.DependenciesDirectory.packageResolvedName)
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]
        
        let dependenciesFilePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return """
                {
                  "version": 2,
                  "pins": [
                    {
                      "identity" : "alamofire",
                      "kind" : "remoteSourceControl",
                      "location" : "https://github.com/Alamofire/Alamofire",
                      "state" : {
                        "revision" : "b2fa556e4e48cbf06cf8c63def138c98f4b811fa",
                        "version" : "5.8.0"
                      }
                    },
                    {
                      "identity" : "combine-schedulers",
                      "kind" : "remoteSourceControl",
                      "location" : "https://github.com/pointfreeco/combine-schedulers",
                      "state" : {
                        "revision" : "9dc9cbe4bc45c65164fa653a563d8d8db61b09bb",
                        "version" : "1.0.0"
                      }
                    }
                  ]
                }
                """.data(using: .utf8)!
            }
        }
        
        try fileHandler.touch(dependenciesFilePath)
        try fileHandler.touch(packageResolvedFile)
        try fileHandler.touch(workspaceStatePath)

        system.swiftVersionStub = { "5.6.0" }
        swiftPackageManagerController.resolveStub = { path, arguments, printOutput in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(arguments, stubbedPassthroughArguments)
            XCTAssertTrue(printOutput)
            try self.simulateSPMOutput(at: path)
        }
        swiftPackageManagerController.setToolsVersionStub = { path, version in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(version, Version(5, 6, 0))
        }

        swiftPackageManagerGraphGenerator
            .generateStub =
            { path, automaticProductType, baseSettings, targetSettings, swiftToolsVersion, projectOptions, resolvedDependenciesVersions in
                XCTAssertEqual(path, swiftPackageManagerBuildDirectory)
                XCTAssertEqual(automaticProductType, [:])
                XCTAssertEqual(baseSettings, .default)
                XCTAssertEqual(targetSettings, [:])
                XCTAssertNil(swiftToolsVersion)
                XCTAssertEqual(projectOptions, [:])
                XCTAssertEqual(resolvedDependenciesVersions, ["alamofire": "5.8.0", "combine-schedulers": "1.0.0"]
                )
                return .test()
            }

        // When
        let dependenciesGraph = try subject.install(
            dependenciesDirectory: dependenciesDirectory,
            packageSettings: .test(baseSettings: .default),
            arguments: stubbedPassthroughArguments,
            shouldUpdate: false,
            swiftToolsVersion: nil
        )

        // Then
        XCTAssertEqual(dependenciesGraph, .test())
    }
    
    func test_resolved_dependencies_versions_shouldBeEmpty() throws {
        // Given
        let rootPath = try TemporaryDirectory(removeTreeOnDeinit: true).path
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)
        let swiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        let swiftPackageManagerBuildDirectory = swiftPackageManagerDirectory.appending(component: ".build")
        let packageResolvedFile = rootPath.appending(component: Constants.DependenciesDirectory.packageResolvedName)
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]
        
        let dependenciesFilePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return """
                    {
                      "version": 2,
                      "pins": []
                    }
                """.data(using: .utf8)!
            }
        }
        
        try fileHandler.touch(dependenciesFilePath)
        try fileHandler.touch(packageResolvedFile)
        try fileHandler.touch(workspaceStatePath)
        fileHandler.stubExists = { path in
            return true
        }
//        
//        let dependencies = SwiftPackageManagerDependencies(
//            .packages([
//                .remote(url: "https://github.com/Alamofire/Alamofire.git", requirement: .upToNextMajor(from: .init(5, 2, 0))),
//            ]),
//            productTypes: [:],
//            baseSettings: .default,
//            targetSettings: [:]
//        )

        system.swiftVersionStub = { "5.6.0" }
        swiftPackageManagerController.resolveStub = { path, arguments, printOutput in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(arguments, stubbedPassthroughArguments)
            XCTAssertTrue(printOutput)
            try self.simulateSPMOutput(at: path)
        }
        swiftPackageManagerController.setToolsVersionStub = { path, version in
            XCTAssertEqual(path, swiftPackageManagerDirectory)
            XCTAssertEqual(version, Version(5, 6, 0))
        }

        swiftPackageManagerGraphGenerator
            .generateStub =
            { path, automaticProductType, baseSettings, targetSettings, swiftToolsVersion, projectOptions, resolvedDependenciesVersions in
                XCTAssertEqual(path, swiftPackageManagerBuildDirectory)
                XCTAssertEqual(automaticProductType, [:])
                XCTAssertEqual(baseSettings, .default)
                XCTAssertEqual(targetSettings, [:])
                XCTAssertNil(swiftToolsVersion)
                XCTAssertEqual(projectOptions, [:])
                XCTAssertEqual(resolvedDependenciesVersions, [:]
                )
                return .test()
            }

        // When
        let dependenciesGraph = try subject.install(
            dependenciesDirectory: dependenciesDirectory,
            packageSettings: .test(baseSettings: .default),
            arguments: stubbedPassthroughArguments,
            shouldUpdate: false,
            swiftToolsVersion: nil
        )

        // Then
        XCTAssertEqual(dependenciesGraph, .test())
    }
    
    func test_needFetch_when_dependencies_not_changed_and_package_file_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [

                    ],
                    "dependencies" : [
                      {
                        "packageRef": {
                          "identity" : "alamofire",
                          "kind": "remote",
                          "name": "Alamofire",
                          "path": "https://github.com/Alamofire/Alamofire"
                        },
                        "subpath": "Alamofire"
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            } else {
                return "".data(using: .utf8)!
            }
        }
        fileHandler.stubReadTextFile = {
            if $0 == packageResolvedFilePath {
                return """
                {
                  "version": 2,
                  "pins": [
                    {
                      "identity" : "alamofire",
                      "kind" : "remoteSourceControl",
                      "location" : "https://github.com/Alamofire/Alamofire",
                      "state" : {
                        "revision" : "b2fa556e4e48cbf06cf8c63def138c98f4b811fa",
                        "version" : "5.8.0"
                      }
                    }
                  ]
                }
                """
            } else {
                return """
                filesHashes:
                  \(rootPath.pathString)/Geko/Package.swift: 2d06800538d394c2
                  \(rootPath.pathString)/Geko/Package.resolved: 2d06800538d394c2
                """
            }
        }
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(packageResolvedFilePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_needFetch_when_dependencies_changed_and_package_file_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [

                    ],
                    "dependencies" : [
                      {
                        "packageRef": {
                          "identity" : "alamofire",
                          "kind": "remote",
                          "name": "Alamofire",
                          "path": "https://github.com/Alamofire/Alamofire"
                        },
                        "subpath": "Alamofire"
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            } else {
                return "".data(using: .utf8)!
            }
        }
        fileHandler.stubReadTextFile = {
            if $0 == packageResolvedFilePath {
                return """
                {
                  "version": 2,
                  "pins": [
                    {
                      "identity" : "alamofire",
                      "kind" : "remoteSourceControl",
                      "location" : "https://github.com/Alamofire/Alamofire",
                      "state" : {
                        "revision" : "b2fa556e4e48cbf06cf8c63def138c98f4b811fa",
                        "version" : "5.8.0"
                      }
                    }
                  ]
                }
                """
            } else {
                return """
                filesHashes:
                  \(rootPath.pathString)/Geko/Package.swift: 2d06800538d394c3
                  \(rootPath.pathString)/Geko/Package.resolved: 2d06800538d394c3
                """
            }
        }
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(packageResolvedFilePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_needFetch_when_dependencies_file_not_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packageResolvedFilePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_needFetch_when_resolved_file_not_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : []
                  }
                }
                """.data(using: .utf8)!
            } else {
                return "".data(using: .utf8)!
            }
        }
        fileHandler.stubReadTextFile = { _ in
            return """
            filesHashes:
              \(rootPath.pathString)/Geko/Package.swift: 2d06800538d394c2
            """
        }
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_needFetch_when_workspace_state_file_not_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(packageResolvedFilePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_needFetch_when_local_dependencies_changed() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : [
                        {
                        "basedOn" : null,
                        "packageRef" : {
                          "identity" : "localswiftpackageb",
                          "kind" : "fileSystem",
                          "location" : "\(rootPath.pathString)/LocalSwiftPackageB",
                          "name" : "LocalSwiftPackageB"
                        },
                        "state" : {
                          "name" : "fileSystem",
                          "path" : "\(rootPath.pathString)/LocalSwiftPackageB"
                        },
                        "subpath" : "localswiftpackageb"
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            } else {
                return "".data(using: .utf8)!
            }
        }
        fileHandler.stubReadTextFile = { _ in
            return """
            filesHashes:
              \(rootPath.pathString)/Geko/Package.swift: 2d06800538d394c2
              \(rootPath.pathString)/LocalSwiftPackageB/Package.swift: 2d06800538d394c3
            """
        }
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func test_needFetch_when_local_dependencies_not_changed() throws {
        // Given
        let rootPath = try temporaryPath()
        let sandboxPackageFilePath = rootPath.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        let localPackageBPath = rootPath.appending(components: ["LocalSwiftPackageB", "Package.swift"])
        
        fileHandler.stubReadFile = {
            if $0 == workspaceStatePath {
                return """
                {
                  "object" : {
                    "artifacts" : [],
                    "dependencies" : [
                        {
                        "basedOn" : null,
                        "packageRef" : {
                          "identity" : "localswiftpackageb",
                          "kind" : "fileSystem",
                          "location" : "\(rootPath.pathString)/LocalSwiftPackageB",
                          "name" : "LocalSwiftPackageB"
                        },
                        "state" : {
                          "name" : "fileSystem",
                          "path" : "\(rootPath.pathString)/LocalSwiftPackageB"
                        },
                        "subpath" : "localswiftpackageb"
                      }
                    ]
                  }
                }
                """.data(using: .utf8)!
            } else {
                return "".data(using: .utf8)!
            }
        }
        fileHandler.stubReadTextFile = { _ in
            return """
            filesHashes:
              \(rootPath.pathString)/Geko/Package.swift: 2d06800538d394c2
              \(rootPath.pathString)/LocalSwiftPackageB/Package.swift: 2d06800538d394c2
            """
        }
        
        try fileHandler.touch(sandboxPackageFilePath)
        try fileHandler.touch(packagePath)
        try fileHandler.touch(workspaceStatePath)
        try fileHandler.touch(localPackageBPath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func test_needFetch_when_sandbox_file_not_exists() throws {
        // Given
        let rootPath = try temporaryPath()
        
        let packageResolvedFilePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let packagePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        try fileHandler.touch(packagePath)
        try fileHandler.touch(packageResolvedFilePath)
        try fileHandler.touch(workspaceStatePath)
        
        // When
        let result = try subject.needFetch(path: rootPath)
        
        // Then
        XCTAssertTrue(result)
    }

    func test_clean() throws {
        // Given
        let rootPath = try temporaryPath()
        let dependenciesDirectory = rootPath
            .appending(component: Constants.DependenciesDirectory.name)

        try createFiles([
            "Dependencies/SwiftPackageManager/Package.swift",
            "Package.resolved",
            "OtherLockfile.lock",
            "Dependencies/SwiftPackageManager/Info.plist",
            "Dependencies/OtherDependenciesManager/bar.bar",
        ])

        // When
        try subject.clean(dependenciesDirectory: dependenciesDirectory)

        // Then
        try XCTAssertDirectoryContentEqual(
            dependenciesDirectory,
            [
                "OtherDependenciesManager"
            ]
        )
        try XCTAssertDirectoryContentEqual(
            rootPath,
            [
                "Dependencies",
                "OtherLockfile.lock"
            ]
        )

        XCTAssertFalse(swiftPackageManagerController.invokedUpdate)
        XCTAssertFalse(swiftPackageManagerController.invokedSetToolsVersion)
        XCTAssertFalse(swiftPackageManagerController.invokedResolve)
    }
}

// MARK: - Helpers

extension SwiftPackageManagerInteractorTests {
    private func simulateSPMOutput(at path: AbsolutePath) throws {
        try [
            "Package.swift",
            "Package.resolved",
            ".build/manifest.db",
            ".build/workspace-state.json",
            ".build/artifacts/foo.txt",
            ".build/checkouts/Alamofire/Info.plist",
            ".build/repositories/checkouts-state.json",
            ".build/repositories/Alamofire-e8f130fe/config",
        ].forEach {
            try fileHandler.touch(path.appending(try RelativePath(validating: $0)))
        }
    }
}
