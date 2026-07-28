import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoDependencies
import GekoGraph
import GekoSupport
import XCTest
@testable import GekoDependenciesTesting
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

class SwiftPackageManagerGraphGeneratorTests: GekoUnitTestCase {
    private var swiftPackageManagerController: MockSwiftPackageManagerController!
    private var subject: SwiftPackageManagerGraphGenerator!
    private var path: AbsolutePath { try! temporaryPath() }
    private var spmFolder: FilePath { path }
    private var checkoutsPath: AbsolutePath { path.appending(component: "checkouts") }

    override func setUp() {
        super.setUp()

        swiftPackageManagerController = MockSwiftPackageManagerController()
        system.swiftVersionStub = { "5.7.0" }
        subject = SwiftPackageManagerGraphGenerator(swiftPackageManagerController: swiftPackageManagerController)
    }

    override func tearDown() {
        swiftPackageManagerController = nil
        subject = nil
        super.tearDown()
    }

    func test_generate_alamofire_spm_pre_v5_6() throws {
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
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
            """,
            loadPackageInfoStub: { packagePath in
                XCTAssertEqual(packagePath, self.path.appending(component: "checkouts").appending(component: "Alamofire"))
                return PackageInfo.alamofire
            },
            dependenciesGraph: DependenciesGraph.alamofire(spmFolder: spmFolder)
        )
    }

    func test_generate_alamofire_spm_v5_6() throws {
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "alamofire",
                  "kind": "remoteSourceControl",
                  "name": "Alamofire",
                  "path": "https://github.com/Alamofire/Alamofire"
                },
                "subpath": "Alamofire"
              }
            ]
            """,
            loadPackageInfoStub: { packagePath in
                XCTAssertEqual(packagePath, self.path.appending(component: "checkouts").appending(component: "Alamofire"))
                return PackageInfo.alamofire
            },
            dependenciesGraph: DependenciesGraph.alamofire(spmFolder: spmFolder)
        )
    }

    // swiftlint:disable:next function_body_length
    func test_generate_resolvesPackageTraitsTransitively() throws {
        let workspacePath = path.appending(component: "workspace-state.json")
        try fileHandler.touch(workspacePath)
        fileHandler.stubReadFile = { requestedPath in
            XCTAssertEqual(requestedPath, workspacePath)
            return Data("""
            {
              "object": {
                "dependencies": [
                  {
                    "packageRef": {
                      "identity": "feature-package",
                      "kind": "remoteSourceControl",
                      "name": "FeaturePackage"
                    },
                    "subpath": "FeaturePackage"
                  },
                  {
                    "packageRef": {
                      "identity": "child-package",
                      "kind": "remoteSourceControl",
                      "name": "ChildPackage"
                    },
                    "subpath": "ChildPackage"
                  }
                ],
                "artifacts": []
              }
            }
            """.utf8)
        }

        let rootPackage = PackageInfo.test(
            name: "Root",
            traits: [
                PackageTrait(enabledTraits: ["WorkspaceFeature"], name: "default", description: nil),
                PackageTrait(enabledTraits: [], name: "WorkspaceFeature", description: nil),
            ],
            dependencies: [
                PackageDependency(
                    identity: "feature-package",
                    traits: [PackageDependencyTrait(name: "default", condition: ["WorkspaceFeature"])]
                ),
            ]
        )
        let featurePackage = PackageInfo.test(
            name: "FeaturePackage",
            targets: [
                PackageInfo.Target(
                    name: "FeatureTarget",
                    path: nil,
                    url: nil,
                    sources: nil,
                    resources: [],
                    exclude: [],
                    dependencies: [
                        .byName(
                            name: "EnabledDependency",
                            condition: .init(platformNames: [], config: nil, traits: ["Feature"])
                        ),
                        .byName(
                            name: "DisabledDependency",
                            condition: .init(platformNames: [], config: nil, traits: ["Other"])
                        ),
                    ],
                    publicHeadersPath: nil,
                    type: .regular,
                    settings: [],
                    checksum: nil
                ),
            ],
            traits: [
                PackageTrait(enabledTraits: ["Feature"], name: "default", description: nil),
                PackageTrait(enabledTraits: [], name: "Feature", description: nil),
            ],
            dependencies: [
                PackageDependency(
                    identity: "child-package",
                    traits: [PackageDependencyTrait(name: "ChildFeature", condition: ["Feature"])]
                ),
            ]
        )
        let childPackage = PackageInfo.test(
            name: "ChildPackage",
            traits: [PackageTrait(enabledTraits: [], name: "ChildFeature", description: nil)]
        )
        swiftPackageManagerController.loadPackageInfoStub = { packagePath in
            switch packagePath {
            case self.path.parentDirectory:
                return rootPackage
            case self.checkoutsPath.appending(component: "FeaturePackage"):
                return featurePackage
            case self.checkoutsPath.appending(component: "ChildPackage"):
                return childPackage
            default:
                XCTFail("Unexpected path: \(packagePath)")
                return .test()
            }
        }
        let packageInfoMapper = RecordingPackageInfoMapper()
        subject = SwiftPackageManagerGraphGenerator(
            swiftPackageManagerController: swiftPackageManagerController,
            packageInfoMapper: packageInfoMapper
        )

        let graph = try subject.generate(
            at: path,
            productTypes: [:],
            baseSettings: .default,
            targetSettings: [:],
            swiftToolsVersion: nil,
            projectOptions: [:],
            resolvedDependenciesVersions: [:]
        )

        XCTAssertEqual(packageInfoMapper.enabledTraits["FeaturePackage"], ["default", "Feature"])
        XCTAssertEqual(packageInfoMapper.enabledTraits["ChildPackage"], ["ChildFeature"])
        XCTAssertEqual(
            Set(try XCTUnwrap(graph.tree["FeaturePackage"]).dependencies),
            ["FeatureTarget", "EnabledDependency"]
        )
    }

    func test_generate_google_measurement() throws {
        try fileHandler.createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/nanopb/Sources/nanopb"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/GoogleUtilities/Sources/GULAppDelegateSwizzler")
            )
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/GoogleUtilities/Sources/GULNSData"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/GoogleUtilities/Sources/GULMethodSwizzler")
            )
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/GoogleUtilities/Sources/GULNetwork"))

        // swiftformat:disable wrap
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "googleappmeasurement",
                  "kind": "remote",
                  "name": "GoogleAppMeasurement",
                  "path": "https://github.com/google/GoogleAppMeasurement"
                },
                "subpath": "GoogleAppMeasurement"
              },
              {
                "packageRef": {
                  "identity" : "googleutilities",
                  "kind": "remote",
                  "name": "GoogleUtilities",
                  "path": "https://github.com/google/GoogleUtilities"
                },
                "subpath": "GoogleUtilities"
              },
              {
                "packageRef": {
                  "identity" : "nanopb",
                  "kind": "remote",
                  "name": "nanopb",
                  "path": "https://github.com/nanopb/nanopb"
                },
                "subpath": "nanopb"
              }
            ]
            """,
            workspaceArtifactsJSON: """
            [
              {
                "packageRef" : {
                  "identity" : "googleappmeasurement",
                  "kind" : "remote",
                  "path" : "https://github.com/google/GoogleAppMeasurement",
                  "name" : "GoogleAppMeasurement"
                },
                "path" : "\(spmFolder.pathString)/artifacts/GoogleAppMeasurement/GoogleAppMeasurement.xcframework",
                "targetName" : "GoogleAppMeasurement"
              },
              {
                "packageRef" : {
                  "identity" : "googleappmeasurement",
                  "kind" : "remote",
                  "path" : "https://github.com/google/GoogleAppMeasurement",
                  "name" : "GoogleAppMeasurement"
                },
                "path" : "\(spmFolder.pathString)/artifacts/GoogleAppMeasurement/GoogleAppMeasurementWithoutAdIdSupport.xcframework",
                "targetName" : "GoogleAppMeasurementWithoutAdIdSupport"
              },
            ]
            """,
            loadPackageInfoStub: { packagePath in
                switch packagePath {
                case self.checkoutsPath.appending(component: "GoogleAppMeasurement"):
                    return PackageInfo.googleAppMeasurement
                case self.checkoutsPath.appending(component: "GoogleUtilities"):
                    return PackageInfo.googleUtilities
                case self.checkoutsPath.appending(component: "nanopb"):
                    return PackageInfo.nanopb
                default:
                    XCTFail("Unexpected path: \(self.path)")
                    return .test
                }
            },
            dependenciesGraph: try DependenciesGraph.googleAppMeasurement(spmFolder: spmFolder)
                .merging(with: DependenciesGraph.googleUtilities(
                    spmFolder: spmFolder,
                    customProductTypes: [
                        "GULMethodSwizzler": .framework,
                        "GULNetwork": .dynamicLibrary,
                    ]
                ))
                .merging(with: DependenciesGraph.nanopb(spmFolder: spmFolder))
        )
        // swiftformat:enable wrap
    }

    func test_generate_test_local_path() throws {
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibrary"))
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibraryUtils"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/another-dependency/Sources/AnotherLibrary")
            )
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/TestUtilities"))

        let testPath = try AbsolutePath(validating: "/tmp/localPackage")
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "test",
                  "kind": "local",
                  "name": "test",
                  "path": "\(testPath.pathString)"
                },
                "subpath": "test"
              },
              {
                "packageRef": {
                  "identity" : "a-dependency",
                  "kind": "remote",
                  "name": "a-dependency"
                },
                "subpath": "ADependency"
              },
              {
                "packageRef": {
                  "identity" : "another-dependency",
                  "kind": "remote",
                  "name": "another-dependency"
                },
                "subpath": "another-dependency"
              }
            ]
            """,
            loadPackageInfoStub: { packagePath in
                switch packagePath {
                case testPath:
                    return PackageInfo.test
                case self.checkoutsPath.appending(component: "ADependency"):
                    return PackageInfo.aDependency
                case self.checkoutsPath.appending(component: "another-dependency"):
                    return PackageInfo.anotherDependency
                default:
                    XCTFail("Unexpected path: \(self.path)")
                    return .test
                }
            },
            dependenciesGraph: DependenciesGraph.test(
                spmFolder: spmFolder,
                packageFolder: testPath,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign],
                fileHandler: fileHandler
            )
            .merging(with: DependenciesGraph.aDependency(
                spmFolder: spmFolder,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
            ))
            .merging(with: DependenciesGraph.anotherDependency(
                spmFolder: spmFolder,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
            ))
        )
    }

    func test_generate_test_local_location_spm_pre_v5_6() throws {
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibrary"))
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibraryUtils"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/another-dependency/Sources/AnotherLibrary")
            )
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/TestUtilities"))
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/GekoKit"))

        let testPath = try AbsolutePath(validating: "/tmp/localPackage")
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "test",
                  "kind": "local",
                  "name": "test",
                  "location": "\(testPath.pathString)"
                },
                "subpath": "test"
              },
              {
                "packageRef": {
                  "identity" : "a-dependency",
                  "kind": "remote",
                  "name": "a-dependency"
                },
                "subpath": "ADependency"
              },
              {
                "packageRef": {
                  "identity" : "another-dependency",
                  "kind": "remote",
                  "name": "another-dependency"
                },
                "subpath": "another-dependency"
              }
            ]
            """,
            loadPackageInfoStub: { packagePath in
                switch packagePath {
                case testPath:
                    return PackageInfo.test
                case self.checkoutsPath.appending(component: "ADependency"):
                    return PackageInfo.aDependency
                case self.checkoutsPath.appending(component: "another-dependency"):
                    return PackageInfo.anotherDependency
                default:
                    XCTFail("Unexpected path: \(self.path)")
                    return .test
                }
            },
            dependenciesGraph: DependenciesGraph.test(
                spmFolder: spmFolder,
                packageFolder: testPath,
                fileHandler: fileHandler
            )
            .merging(with: DependenciesGraph.aDependency(spmFolder: spmFolder))
            .merging(with: DependenciesGraph.anotherDependency(spmFolder: spmFolder))
        )
    }

    func test_generate_test_fileSystem_location_spm_v5_6() throws {
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibrary"))
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibraryUtils"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/another-dependency/Sources/AnotherLibrary")
            )
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/TestUtilities"))
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/GekoKit"))

        let testPath = try AbsolutePath(validating: "/tmp/localPackage")
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "test",
                  "kind": "fileSystem",
                  "name": "test",
                  "location": "\(testPath.pathString)"
                },
                "subpath": "test"
              },
              {
                "packageRef": {
                  "identity" : "a-dependency",
                  "kind": "remoteSourceControl",
                  "name": "a-dependency"
                },
                "subpath": "ADependency"
              },
              {
                "packageRef": {
                  "identity": "another-dependency",
                  "kind": "remoteSourceControl",
                  "name": "another-dependency"
                },
                "subpath": "another-dependency"
              }
            ]
            """,
            loadPackageInfoStub: { packagePath in
                switch packagePath {
                case testPath:
                    return PackageInfo.test
                case self.checkoutsPath.appending(component: "ADependency"):
                    return PackageInfo.aDependency
                case self.checkoutsPath.appending(component: "another-dependency"):
                    return PackageInfo.anotherDependency
                default:
                    XCTFail("Unexpected path: \(self.path)")
                    return .test
                }
            },
            dependenciesGraph: DependenciesGraph.test(
                spmFolder: spmFolder,
                packageFolder: testPath,
                fileHandler: fileHandler
            )
            .merging(with: DependenciesGraph.aDependency(spmFolder: spmFolder))
            .merging(with: DependenciesGraph.anotherDependency(spmFolder: spmFolder))
        )
    }

    func test_generate_test_localSourceControl_location_spm_v5_6() throws {
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibrary"))
        try fileHandler
            .createFolder(try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/ADependency/Sources/ALibraryUtils"))
        try fileHandler
            .createFolder(
                try AbsolutePath(validating: "\(spmFolder.pathString)/checkouts/another-dependency/Sources/AnotherLibrary")
            )
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/GekoKit"))

        let testPath = try AbsolutePath(validating: "/tmp/localPackage")
        try checkGenerated(
            workspaceDependenciesJSON: """
            [
              {
                "packageRef": {
                  "identity" : "test",
                  "kind": "localSourceControl",
                  "name": "test",
                  "location": "\(testPath.pathString)"
                },
                "subpath": "test"
              },
              {
                "packageRef": {
                  "identity" : "a-dependency",
                  "kind": "remoteSourceControl",
                  "name": "a-dependency"
                },
                "subpath": "ADependency"
              },
              {
                "packageRef": {
                  "identity": "another-dependency",
                  "kind": "remoteSourceControl",
                  "name": "another-dependency"
                },
                "subpath": "another-dependency"
              }
            ]
            """,
            loadPackageInfoStub: { packagePath in
                switch packagePath {
                case testPath:
                    return PackageInfo.test
                case self.checkoutsPath.appending(component: "ADependency"):
                    return PackageInfo.aDependency
                case self.checkoutsPath.appending(component: "another-dependency"):
                    return PackageInfo.anotherDependency
                default:
                    XCTFail("Unexpected path: \(self.path)")
                    return .test
                }
            },
            dependenciesGraph: DependenciesGraph.test(
                spmFolder: spmFolder,
                packageFolder: testPath,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign],
                fileHandler: fileHandler
            )
            .merging(with: DependenciesGraph.aDependency(
                spmFolder: spmFolder,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
            ))
            .merging(with: DependenciesGraph.anotherDependency(
                spmFolder: spmFolder,
                destinations: [.iPhone, .iPad, .macWithiPadDesign, .appleVisionWithiPadDesign]
            ))
        )
    }

    private func checkGenerated(
        workspaceDependenciesJSON: String,
        workspaceArtifactsJSON: String = "[]",
        loadPackageInfoStub: @escaping (AbsolutePath) -> PackageInfo,
        dependenciesGraph: GekoCore.DependenciesGraph
    ) throws {
        // Given
        try fileHandler.createFolder(try AbsolutePath(validating: "/tmp/localPackage/Sources/TestUtilities"))
        let workspacePath = self.path.appending(component: "workspace-state.json")
        try fileHandler.touch(workspacePath)

        fileHandler.stubReadFile = {
            XCTAssertEqual($0, workspacePath)
            return """
            {
              "object": {
                "dependencies": \(workspaceDependenciesJSON),
                "artifacts": \(workspaceArtifactsJSON)
              }
            }
            """.data(using: .utf8)!
        }

        fileHandler.stubIsFolder = { _ in
            // called to convert globs to AbsolutePath
            true
        }

        swiftPackageManagerController.loadPackageInfoStub = { packagePath in
            if packagePath == self.path.parentDirectory {
                return .test(name: "Root")
            }
            return loadPackageInfoStub(packagePath)
        }

        // When
        let got = try subject.generate(
            at: path,
            productTypes: [
                "GULMethodSwizzler": .framework,
                "GULNetwork": .dynamicLibrary,
            ],
            baseSettings: .default,
            targetSettings: [:],
            swiftToolsVersion: nil,
            projectOptions: [:],
            resolvedDependenciesVersions: [:]
        )

        // Then
        XCTAssertEqual(got.externalDependencies.map { "\($0.key):\($0.value)"}.sorted(), dependenciesGraph.externalDependencies.map { "\($0.key):\($0.value)"}.sorted())
        XCTAssertEqual(got.externalFrameworkDependencies.map { "\($0.key):\($0.value)"}.sorted(), dependenciesGraph.externalFrameworkDependencies.map { "\($0.key):\($0.value)"}.sorted())
        XCTAssertEqual(got.externalProjects.map { "\($0.key):\($0.value)"}.sorted(), dependenciesGraph.externalProjects.map { "\($0.key):\($0.value)"}.sorted())
        XCTAssertEqual(got.tree.map { "\($0.key):\($0.value.dependencies.sorted())"}.sorted(), dependenciesGraph.tree.map { "\($0.key):\($0.value.dependencies.sorted())"}.sorted())
    }
}

private final class RecordingPackageInfoMapper: PackageInfoMapping {
    var enabledTraits: [String: Set<String>] = [:]

    func resolveExternalDependencies(
        path _: AbsolutePath,
        packageInfos _: [String: PackageInfo],
        packageToFolder _: [String: AbsolutePath],
        packageToTargetsToArtifactPaths _: [String: [String: AbsolutePath]],
        packageModuleAliases _: [String: [String: String]]
    ) throws -> [String: [ProjectDescription.TargetDependency]] {
        [:]
    }

    func map(
        packageInfo: PackageInfo,
        path _: AbsolutePath,
        productTypes _: [String: Product],
        baseSettings _: Settings,
        targetSettings _: [String: Settings],
        projectOptions _: ProjectDescription.Project.Options?,
        targetsToArtifactPaths _: [String: AbsolutePath],
        packageModuleAliases _: [String: [String: String]],
        enabledTraits: Set<String>
    ) throws -> ProjectDescription.Project? {
        self.enabledTraits[packageInfo.name] = enabledTraits
        return nil
    }
}

extension GekoCore.DependenciesGraph {
    public func merging(with other: Self) throws -> Self {
        var mergedExternalDependencies: [String: [ProjectDescription.TargetDependency]] =
            externalDependencies

        for (name, dependency) in other.externalDependencies {
            if let alreadyPresent = mergedExternalDependencies[name] {
                fatalError("Dupliacted Entry(\(name), \(alreadyPresent), \(dependency)")
            }
            mergedExternalDependencies[name] = dependency
        }

        let mergedExternalProjects = other.externalProjects.reduce(into: externalProjects) { result, entry in
            if let alreadyPresent = result[entry.key] {
                fatalError("Dupliacted Entry(\(entry.key), \(alreadyPresent), \(entry.value)")
            }
            result[entry.key] = entry.value
        }
        
        let mergedTree = tree.merging(other.tree) { first, second in
            fatalError("Dupliacted Tree\(first.dependencies), \(second.dependencies)")
        }

        return .init(
            externalDependencies: mergedExternalDependencies,
            externalProjects: mergedExternalProjects,
            externalFrameworkDependencies: [:],
            tree: mergedTree
        )
    }
}
