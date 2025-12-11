import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
import GekoDependencies

@testable import GekoGenerator
@testable import GekoSupportTesting

final class ImpactAnalysisGraphMapperTests: GekoUnitTestCase {
    func test_map_removesRedundantDependenciesFromSharedTarget() async throws {
        // given
        let workspacePath = try temporaryPath()

        let environment = try MockEnvironment()
        let system = MockSystem()

        let subject = ImpactAnalysisGraphMapper(
            environment: environment,
            system: system
        )

        var sideTable = GraphSideTable()

        func set(_ flags: TargetFlags, path: AbsolutePath, name: String) {
            sideTable.workspace.projects[path, default: .init()]
                .targets[name, default: .init()].flags = flags
        }
        func setSourcesGlobs(_ sources: [SourceFiles], path: AbsolutePath, name: String) {
            sideTable.workspace.projects[path, default: .init()]
                .targets[name, default: .init()].sources = sources
        }

        let aProjectPath = workspacePath.appending(component: "CoreFramework")
        let aSourceFilePath = aProjectPath.appending(components: "Sources", "File.swift")
        let aTarget = Target.test(
            name: "CoreFramework",
            product: .staticFramework,
            sources: [
                SourceFiles(paths: [aSourceFilePath])
            ]
        )
        let aTargetTests = Target.test(name: "CoreFramework-Unit-Tests", product: .unitTests)
        let aTargetTestsFramework = Target.test(name: "CoreFramework-Unit-TestsGekoGenerated", product: .staticFramework)
        let aProject = Project.test(
            path: aProjectPath, name: "CoreFramework",
            targets: [aTarget, aTargetTests, aTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: aProjectPath, name: aTargetTestsFramework.name)

        let bTarget = Target.test(name: "Framework1", product: .staticFramework)
        let bTargetTests = Target.test(name: "Framework1-Unit-Tests", product: .unitTests)
        let bTargetTestsFramework = Target.test(name: "Framework1-Unit-TestsGekoGenerated", product: .staticFramework)
        let bProjectPath = workspacePath.appending(component: "Framework1")
        let bProject = Project.test(
            path: bProjectPath, name: "Framework1",
            targets: [bTarget, bTargetTests, bTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: bProjectPath, name: bTargetTestsFramework.name)

        let cTarget = Target.test(name: "Framework2", product: .staticFramework)
        let cTargetTests = Target.test(name: "Framework2-Unit-Tests", product: .unitTests)
        let cTargetTestsFramework = Target.test(name: "Framework2-Unit-TestsGekoGenerated", product: .staticFramework)
        let cProjectPath = workspacePath.appending(component: "Framework2")
        let cProject = Project.test(
            path: cProjectPath, name: "Framework2",
            targets: [cTarget, cTargetTests, cTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: cProjectPath, name: cTargetTestsFramework.name)

        let dTarget = Target.test(name: "Framework3", product: .staticFramework)
        let dTargetTests = Target.test(name: "Framework3-Unit-Tests", product: .unitTests)
        let dTargetTestsFramework = Target.test(name: "Framework3-Unit-TestsGekoGenerated", product: .staticFramework)
        let dProjectPath = workspacePath.appending(component: "Framework3")
        let dProject = Project.test(
            path: dProjectPath, name: "Framework3",
            targets: [dTarget, dTargetTests, dTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: dProjectPath, name: dTargetTestsFramework.name)

        let eProjectPath = workspacePath.appending(component: "Framework4")
        let eResourceFilePath = eProjectPath.appending(components: "Resources", "image.png")
        let eTarget = Target.test(
            name: "Framework4",
            product: .framework,
            resources: [
                .file(path: eResourceFilePath)
            ]
        )
        let eTargetTests = Target.test(name: "Framework4-Unit-Tests", product: .unitTests)
        let eTargetTestsFramework = Target.test(name: "Framework4-Unit-TestsGekoGenerated", product: .staticFramework)
        let eProject = Project.test(
            path: eProjectPath, name: "Framework4",
            targets: [eTarget, eTargetTests, eTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: eProjectPath, name: eTargetTestsFramework.name)

        let fTarget = Target.test(name: "Framework5", product: .staticFramework)
        let fTargetTests = Target.test(name: "Framework5-Unit-Tests", product: .unitTests)
        let fTargetTestsFramework = Target.test(name: "Framework5-Unit-TestsGekoGenerated", product: .staticFramework)
        let fProjectPath = workspacePath.appending(component: "Framework5")
        let fProject = Project.test(
            path: fProjectPath, name: "Framework5",
            targets: [fTarget, fTargetTests, fTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: fProjectPath, name: fTargetTestsFramework.name)
        
        let gProjectPath = workspacePath.appending(component: "Framework6")
        let gSourceFilePath = gProjectPath.appending(components: "Sources", "File6.swift")
        let gSourceFilesGlob = SourceFiles(paths: [FilePath("Framework6/Sources/**/*.swift")])
        let gTarget = Target.test(
            name: "Framework6",
            product: .staticFramework
        )
        let gTargetTests = Target.test(name: "Framework6-Unit-Tests", product: .unitTests)
        let gTargetTestsFramework = Target.test(name: "Framework6-Unit-TestsGekoGenerated", product: .staticFramework)
        let gProject = Project.test(
            path: gProjectPath, name: "Framework6",
            targets: [gTarget, gTargetTests, gTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: gProjectPath, name: gTargetTestsFramework.name)
        setSourcesGlobs([gSourceFilesGlob], path: gProjectPath, name: gTarget.name)

        let sharedTarget = Target.test(name: "SharedTarget", product: .unitTests)
        let sharedTargetProjectPath = workspacePath.appending(component: "SharedTarget")
        let sharedTargetProject = Project.test(
            path: sharedTargetProjectPath, name: "SharedTarget",
            targets: [sharedTarget]
        )
        set(.sharedTestTarget, path: sharedTargetProjectPath, name: sharedTarget.name)

        var graph = Graph.test(
            workspace: .test(
                path: workspacePath,
                xcWorkspacePath: workspacePath,
                projects: [
                    aProjectPath,
                    bProjectPath,
                    cProjectPath,
                    dProjectPath,
                    eProjectPath,
                    fProjectPath,
                    gProjectPath,
                    sharedTargetProjectPath,
                ],
                generationOptions: .test(
                    generateSharedTestTarget: .init(
                        installTo: sharedTargetProject.name,
                        targets: [
                            .generate(name: "SharedTarget", testsPattern: ".*-Unit-Tests")
                        ]
                    )
                )
            ),
            projects: [
                aProjectPath: aProject,
                bProjectPath: bProject,
                cProjectPath: cProject,
                dProjectPath: dProject,
                eProjectPath: eProject,
                fProjectPath: fProject,
                gProjectPath: gProject,
                sharedTargetProjectPath: sharedTargetProject,
            ],
            targets: [
                aProjectPath: [
                    aTarget.name: aTarget,
                    aTargetTests.name: aTargetTests,
                    aTargetTestsFramework.name: aTargetTestsFramework,
                ],
                bProjectPath: [
                    bTarget.name: bTarget,
                    bTargetTests.name: bTargetTests,
                    bTargetTestsFramework.name: bTargetTestsFramework,
                ],
                cProjectPath: [
                    cTarget.name: cTarget,
                    cTargetTests.name: cTargetTests,
                    cTargetTestsFramework.name: cTargetTestsFramework,
                ],
                dProjectPath: [
                    dTarget.name: dTarget,
                    dTargetTests.name: dTargetTests,
                    dTargetTestsFramework.name: dTargetTestsFramework,
                ],
                eProjectPath: [
                    eTarget.name: eTarget,
                    eTargetTests.name: eTargetTests,
                    eTargetTestsFramework.name: eTargetTestsFramework,
                ],
                fProjectPath: [
                    fTarget.name: fTarget,
                    fTargetTests.name: fTargetTests,
                    fTargetTestsFramework.name: fTargetTestsFramework,
                ],
                gProjectPath: [
                    gTarget.name: gTarget,
                    gTargetTests.name: gTargetTests,
                    gTargetTestsFramework.name: gTargetTestsFramework,
                ],
                sharedTargetProjectPath: [
                    sharedTarget.name: sharedTarget
                ],
            ],
            dependencies: [
                // CoreFramework-Unit-Tests -> CoreFramework
                .target(name: aTargetTests.name, path: aProjectPath): [
                    .target(name: aTarget.name, path: aProjectPath)
                ],
                // CoreFramework-Unit-TestsGekoGenerated -> Framework
                .target(name: aTargetTestsFramework.name, path: aProjectPath): [
                    .target(name: aTarget.name, path: aProjectPath)
                ],

                // Framework1 -> CoreFramework
                .target(name: bTarget.name, path: bProjectPath): [
                    .target(name: aTarget.name, path: aProjectPath)
                ],
                // Framework1-Unit-Tests -> Framework1
                .target(name: bTargetTests.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],
                // Framework1-Unit-TestsGekoGenerated -> Framework1
                .target(name: bTargetTestsFramework.name, path: bProjectPath): [
                    .target(name: bTarget.name, path: bProjectPath)
                ],

                // Framework2 -> CoreFramework
                .target(name: cTarget.name, path: cProjectPath): [
                    .target(name: aTarget.name, path: aProjectPath)
                ],
                // Framework2-Unit-Tests -> Framework2
                .target(name: cTargetTests.name, path: cProjectPath): [
                    .target(name: cTarget.name, path: cProjectPath)
                ],
                // Framework2-Unit-TestsGekoGenerated -> Framework2
                .target(name: cTargetTestsFramework.name, path: cProjectPath): [
                    .target(name: cTarget.name, path: cProjectPath)
                ],

                // Framework3 does not depend on CoreFramework
                // Framework3-Unit-Tests -> Framework3
                .target(name: dTargetTests.name, path: dProjectPath): [
                    .target(name: dTarget.name, path: dProjectPath)
                ],
                // Framework3-Unit-TestsGekoGenerated -> Framework3
                .target(name: dTargetTestsFramework.name, path: dProjectPath): [
                    .target(name: dTarget.name, path: dProjectPath)
                ],

                // Framework4 does not depend on CoreFramework
                // Framework4-Unit-Tests -> Framework4
                .target(name: eTargetTests.name, path: eProjectPath): [
                    .target(name: eTarget.name, path: eProjectPath)
                ],
                // Framework4-Unit-TestsGekoGenerated -> Framework4
                .target(name: eTargetTestsFramework.name, path: eProjectPath): [
                    .target(name: eTarget.name, path: eProjectPath)
                ],

                // Framework5 does not depend on CoreFramework
                // Framework5-Unit-Tests -> Framework5
                .target(name: fTargetTests.name, path: fProjectPath): [
                    .target(name: fTarget.name, path: fProjectPath)
                ],
                // Framework5-Unit-TestsGekoGenerated -> Framework5
                .target(name: fTargetTestsFramework.name, path: fProjectPath): [
                    .target(name: fTarget.name, path: fProjectPath)
                ],
                
                // Framework6-Unit-Tests -> Framework6
                .target(name: gTargetTests.name, path: gProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath)
                ],
                // Framework6-Unit-TestsGekoGenerated -> Framework6
                .target(name: gTargetTestsFramework.name, path: gProjectPath): [
                    .target(name: gTarget.name, path: gProjectPath)
                ],

                .target(name: sharedTarget.name, path: sharedTargetProjectPath): [
                    // SharedTarget -> CoreFramework-Unit-TestsGekoGenerated
                    .target(name: aTargetTestsFramework.name, path: aProjectPath),
                    // SharedTarget -> Framework1-Unit-TestsGekoGenerated
                    .target(name: bTargetTestsFramework.name, path: bProjectPath),
                    // SharedTarget -> Framework2-Unit-TestsGekoGenerated
                    .target(name: cTargetTestsFramework.name, path: cProjectPath),
                    // SharedTarget -> Framework3-Unit-TestsGekoGenerated
                    .target(name: dTargetTestsFramework.name, path: dProjectPath),
                    // SharedTarget -> Framework4-Unit-TestsGekoGenerated
                    .target(name: eTargetTestsFramework.name, path: eProjectPath),
                    // SharedTarget -> Framework5-Unit-TestsGekoGenerated
                    .target(name: fTargetTestsFramework.name, path: fProjectPath),
                    // SharedTarget -> Framework6-Unit-TestsGekoGenerated
                    .target(name: gTargetTestsFramework.name, path: gProjectPath),
                ]
            ],
            externalDependenciesGraph: DependenciesGraph(
                externalDependencies: ["VeryCoolPod": [.project(target: aTarget.name, path: aProjectPath)]],
                externalProjects: [:],
                externalFrameworkDependencies: [:],
                tree: [:]
            )
        )

        environment.impactTargetRef = "targetRef"
        environment.impactAnalysisChangedTargets = [fTarget.name]
        system.succeedCommand(
            ["git", "diff", "targetRef...HEAD", "--name-only", "--no-renames", "--diff-filter=d"],
            output: """
                Geko/Dependencies/Cocoapods.lock
                \(eResourceFilePath.relative(to: workspacePath))
                """
        )
        system.succeedCommand(
            ["git", "diff", "targetRef...HEAD", "--name-only", "--no-renames", "--diff-filter=D"],
            output: """
                \(gSourceFilePath.relative(to: workspacePath))
                """
        )

        let oldLockfile = """
            https://cocoapods-cdn.company.com/private-specs/:
              pods:
                VeryCoolPod:
                  hash: b0dfe3d9b1834aa3827b1211a48b4a60e007c965
                  version: 1.5.0

              type: cdn
            """
        
        let newLockfile = """
            https://cocoapods-cdn.company.com/private-specs/:
              pods:
                VeryCoolPod:
                  hash: b1dfe3d9b1834aa3827b1211a48b4a60e007c965
                  version: 1.6.0

              type: cdn
            """

        system.succeedCommand(
            ["git", "show", "targetRef:Geko/Dependencies/Cocoapods.lock"], output: oldLockfile
        )
        system.succeedCommand(
            ["git", "show", "HEAD:Geko/Dependencies/Cocoapods.lock"], output: newLockfile
        )

        // When

        _ = try await subject.map(
            graph: &graph,
            sideTable: &sideTable
        )

        // Then
        _ = try XCTUnwrap(
            graph.projects[dProjectPath]!.targets.firstIndex(where: { $0.name == dTargetTestsFramework.name })
        )
        XCTAssertTrue(
            graph.targets[dProjectPath]![dTargetTestsFramework.name]!.prune == true
        )

        _ = try XCTUnwrap(
            graph.projects[sharedTargetProjectPath]!.targets.firstIndex(where: {
                $0.name == sharedTarget.name
            })
        )
        XCTAssertEqual(
            graph.dependencies[.target(name: sharedTarget.name, path: sharedTargetProjectPath)],
            [
                // SharedTarget -> CoreFramework-Unit-TestsGekoGenerated
                // because CoreFramework was changed in Cocoapods.lock
                .target(name: aTargetTestsFramework.name, path: aProjectPath),
                // SharedTarget -> Framework1-Unit-TestsGekoGenerated
                // because bTarget depends on CoreFramework whichwas changed
                .target(name: bTargetTestsFramework.name, path: bProjectPath),
                // SharedTarget -> Framework2-Unit-TestsGekoGenerated
                // because cTarget's source file was changed
                .target(name: cTargetTestsFramework.name, path: cProjectPath),
                // SharedTarget -> Framework4-Unit-TestsGekoGenerated
                // because eTarget's resource file was changed
                .target(name: eTargetTestsFramework.name, path: eProjectPath),
                // SharedTarget -> Framework5-Unit-TestsGekoGenerated
                // because fTarget was marked as changed through env var
                .target(name: fTargetTestsFramework.name, path: fProjectPath),
                // SharedTarget -> Framework6-Unit-TestsGekoGenerated
                // because gTarget's source file was deleted
                .target(name: gTargetTestsFramework.name, path: gProjectPath)
            ],
            "Dependency SharedTarget -> Framework3 must be removed from dependencies graph"
        )
    }
}
