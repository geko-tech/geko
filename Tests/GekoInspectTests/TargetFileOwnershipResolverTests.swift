import Foundation
import GekoGraph
import GekoGraphTesting
import GekoSupport
import GekoSupportTesting
@testable import GekoInspect
import ProjectDescription
import XCTest

final class TargetFileOwnershipResolverTests: GekoUnitTestCase {
    private var subject: TargetFileOwnershipResolver!

    override func setUp() {
        super.setUp()
        subject = TargetFileOwnershipResolver()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    // MARK: - General

    func test_resolve_preservesInputOrderAndReturnsUnknownFiles() throws {
        let target = Target.test(sources: ["/repo/Sources/App.swift"])
        let files: [AbsolutePath] = ["/repo/Unknown.swift", "/repo/Sources/App.swift"]

        let result = try subject.resolve(files, graph: makeGraph(targets: [target]))

        XCTAssertEqual(result.map(\.file), files)
        XCTAssertEqual(result.map { $0.targets.map(\.target.name) }, [[], [target.name]])
    }

    func test_resolve_returnsEveryOwnerInDeterministicOrder() throws {
        let file: AbsolutePath = "/repo/Shared.swift"
        let targets = [
            Target.test(name: "Beta", sources: [.glob(file)]),
            Target.test(name: "Alpha", additionalFiles: [.file(path: file)]),
        ]

        let result = try subject.resolve([file], graph: makeGraph(targets: targets))

        XCTAssertEqual(result.first?.targets.map(\.target.name), ["Alpha", "Beta"])
    }

    func test_resolve_returnsNoResultsForEmptyInput() throws {
        XCTAssertEqual(try subject.resolve([], graph: makeGraph()), [])
    }

    // MARK: - Sources

    func test_sourcesMatchExactAndGlobbedFilesWithoutReadingTheFilesystem() throws {
        let target = Target.test(sources: [
            "/repo/Sources/App.swift",
            "/repo/Features/**/*.swift",
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Sources/App.swift",
                "/repo/Features/Payments.swift",
                "/repo/Features/Payments/DeletedView.swift",
            ],
            doesNotOwn: ["/repo/Sources/Other.swift"]
        )
    }

    func test_sourceGlobDoesNotCrossDirectoriesUnlessItUsesDoubleStar() throws {
        let target = Target.test(sources: ["/repo/Sources/*.swift"])

        try assertOwnership(
            target,
            owns: ["/repo/Sources/App.swift"],
            doesNotOwn: ["/repo/Sources/Feature/App.swift"]
        )
    }

    func test_sourceExclusionsApplyWithinEachDeclaration() throws {
        let target = Target.test(sources: [
            .glob(
                "/repo/Sources/**/*.swift",
                excluding: [
                    "/repo/Sources/Generated/**",
                    "/repo/Sources/Legacy.swift",
                    "/repo/Elsewhere/**",
                ]
            ),
            .glob("/repo/Sources/Generated/Kept.swift"),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Sources/App.swift",
                "/repo/Sources/Generated/Kept.swift",
            ],
            doesNotOwn: [
                "/repo/Sources/Generated/Other.swift",
                "/repo/Sources/Legacy.swift",
            ]
        )
    }

    func test_sourceDeclarationMayContainSeveralIncludes() throws {
        let target = Target.test(sources: [
            SourceFiles(paths: ["/repo/Sources/One.swift", "/repo/Sources/Two.swift"]),
        ])

        try assertOwnership(
            target,
            owns: ["/repo/Sources/One.swift", "/repo/Sources/Two.swift"],
            doesNotOwn: ["/repo/Sources/Three.swift"]
        )
    }
    
    func test_sourceLiteralPathOwnsDescendants() throws {
        let target = Target.test(sources: [
            "/repo/Sources/Feature",
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Sources/Feature",
                "/repo/Sources/Feature/View.swift",
                "/repo/Sources/Feature/Nested/DeletedView.swift",
            ],
            doesNotOwn: [
                "/repo/Sources/Feature2/View.swift",
            ]
        )
    }
    
    func test_sourceLiteralExclusionExcludesEntireSubtree() throws {
        let target = Target.test(sources: [
            .glob(
                "/repo/Sources/**",
                excluding: [
                    "/repo/Sources/Generated",
                ]
            ),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Sources/App/View.swift",
            ],
            doesNotOwn: [
                "/repo/Sources/Generated",
                "/repo/Sources/Generated/File.swift",
                "/repo/Sources/Generated/Nested/File.swift",
            ]
        )
    }

    // MARK: - Resources and additional files

    func test_resourcesPreserveFileFolderAndGlobSemantics() throws {
        let target = Target.test(resources: [
            .file(path: "/repo/Resources/Config.json"),
            .folderReference(path: "/repo/Resources/Templates"),
            .glob(pattern: "/repo/Resources/Images/**/*.png"),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Resources/Config.json",
                "/repo/Resources/Templates",
                "/repo/Resources/Templates/Deleted/Page.json",
                "/repo/Resources/Images/Icons/Add.png",
            ],
            doesNotOwn: [
                "/repo/Resources/Config.json/Child",
                "/repo/Resources/Templates2/Page.json",
                "/repo/Resources/Images/Icons/Add.jpg",
            ]
        )
    }

    func test_resourceGlobRespectsExclusions() throws {
        let target = Target.test(resources: [
            .glob(
                pattern: "/repo/Resources/**/*.json",
                excluding: ["/repo/Resources/Generated/**"]
            ),
        ])

        try assertOwnership(
            target,
            owns: ["/repo/Resources/Config.json"],
            doesNotOwn: ["/repo/Resources/Generated/Config.json"]
        )
    }

    func test_additionalFilesPreserveFileFolderAndGlobSemantics() throws {
        let target = Target.test(additionalFiles: [
            .file(path: "/repo/Docs/README.md"),
            .folderReference(path: "/repo/Docs/Guides"),
            .glob(pattern: "/repo/Config/**/*.yml"),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Docs/README.md",
                "/repo/Docs/Guides/Deleted.md",
                "/repo/Config/CI/build.yml",
            ],
            doesNotOwn: [
                "/repo/Docs/README.md/Child",
                "/repo/Docs/Guides2/Guide.md",
            ]
        )
    }
    
    func test_resourceLiteralGlobOwnsDescendants() throws {
        let target = Target.test(resources: [
            .glob(pattern: "/repo/Resources/Images.xcassets"),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Resources/Images.xcassets",
                "/repo/Resources/Images.xcassets/Contents.json",
                "/repo/Resources/Images.xcassets/AppIcon.appiconset/Contents.json",
                "/repo/Resources/Images.xcassets/AppIcon.appiconset/AppIcon.png",
            ],
            doesNotOwn: [
                "/repo/Resources/Images.xcassets2/AppIcon.png",
                "/repo/Resources/Other.xcassets/AppIcon.png",
            ]
        )
    }
    
    func test_resourceLiteralGlobExclusionExcludesEntireSubtree() throws {
        let target = Target.test(resources: [
            .glob(
                pattern: "/repo/Resources/**",
                excluding: [
                    "/repo/Resources/Generated",
                ]
            ),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Resources/Images.xcassets/AppIcon.appiconset/AppIcon.png",
            ],
            doesNotOwn: [
                "/repo/Resources/Generated",
                "/repo/Resources/Generated/image.png",
                "/repo/Resources/Generated/Nested/image.png",
            ]
        )
    }
    
    func test_additionalFilesLiteralGlobOwnsDescendants() throws {
        let target = Target.test(additionalFiles: [
            .glob(pattern: "/repo/Config"),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Config",
                "/repo/Config/settings.yml",
                "/repo/Config/CI/deleted.yml",
            ],
            doesNotOwn: [
                "/repo/Configuration/settings.yml",
            ]
        )
    }

    // MARK: - Buildable folders

    func test_buildableFolderOwnsTheFolderAndAllDescendants() throws {
        let target = Target.test(buildableFolders: [BuildableFolder("/repo/App", exceptions: [])])

        try assertOwnership(
            target,
            owns: [
                "/repo/App",
                "/repo/App/View.swift",
                "/repo/App/Features/DeletedView.swift",
            ],
            doesNotOwn: ["/repo/Application/View.swift"]
        )
    }

    func test_buildableFolderExceptionsExcludeFilesAndSubtrees() throws {
        let target = Target.test(buildableFolders: [
            BuildableFolder(
                "/repo/App",
                exceptions: [
                    "/repo/App/Info.plist",
                    "/repo/App/Generated",
                    "/repo/App/Fixtures/**/*.json",
                ]
            ),
        ])

        try assertOwnership(
            target,
            owns: ["/repo/App/Sources/App.swift"],
            doesNotOwn: [
                "/repo/App/Info.plist",
                "/repo/App/Generated/Nested/File.swift",
                "/repo/App/Fixtures/Deep/value.json",
            ]
        )
    }

    func test_anotherBuildableFolderMayRestoreOwnershipExcludedByTheFirst() throws {
        let target = Target.test(buildableFolders: [
            BuildableFolder("/repo/App", exceptions: ["/repo/App/Generated"]),
            BuildableFolder("/repo/App/Generated", exceptions: []),
        ])

        try assertOwnership(target, owns: ["/repo/App/Generated/File.swift"])
    }

    // MARK: - Target configuration files

    func test_infoPlistFileIsOwnedAsAnExactPath() throws {
        let target = Target.test(infoPlist: .file(path: "/repo/App/Info.plist"))

        try assertOwnership(
            target,
            owns: ["/repo/App/Info.plist"],
            doesNotOwn: ["/repo/App/Other.plist", "/repo/App/Info.plist/Child"]
        )
    }

    func test_generatedAndInlineInfoPlistsAreNotOwned() throws {
        let generated = Target.test(infoPlist: .generatedFile(path: "/repo/Generated.plist", data: Data()))
        let dictionary = Target.test(infoPlist: .dictionary([:]))
        let defaults = Target.test(infoPlist: .default)

        try assertOwnership(generated, doesNotOwn: ["/repo/Generated.plist"])
        try assertOwnership(dictionary, doesNotOwn: ["/repo/Info.plist"])
        try assertOwnership(defaults, doesNotOwn: ["/repo/Info.plist"])
    }

    func test_entitlementsFileIsOwnedAsAnExactPath() throws {
        let target = Target.test(entitlements: .file(path: "/repo/App/App.entitlements"))

        try assertOwnership(
            target,
            owns: ["/repo/App/App.entitlements"],
            doesNotOwn: ["/repo/App/Other.entitlements", "/repo/App/App.entitlements/Child"]
        )
    }

    func test_generatedAndInlineEntitlementsAreNotOwned() throws {
        let generated = Target.test(
            entitlements: .generatedFile(path: "/repo/Generated.entitlements", data: Data())
        )
        let dictionary = Target.test(entitlements: .dictionary([:]))

        try assertOwnership(generated, doesNotOwn: ["/repo/Generated.entitlements"])
        try assertOwnership(dictionary, doesNotOwn: ["/repo/App.entitlements"])
    }

    func test_playgroundsAreExactOwnedPaths() throws {
        let target = Target.test(playgrounds: ["/repo/Demo.playground"])

        try assertOwnership(
            target,
            owns: ["/repo/Demo.playground"],
            doesNotOwn: ["/repo/Other.playground", "/repo/Demo.playground/Contents.swift"]
        )
    }

    func test_coreDataModelOwnsItsPackageContents() throws {
        let target = Target.test(coreDataModels: [
            CoreDataModel(
                "/repo/Models/App.xcdatamodeld",
                versions: ["/repo/Models/App.xcdatamodeld/V2.xcdatamodel"]
            ),
        ])

        try assertOwnership(
            target,
            owns: [
                "/repo/Models/App.xcdatamodeld",
                "/repo/Models/App.xcdatamodeld/.xccurrentversion",
                "/repo/Models/App.xcdatamodeld/V2.xcdatamodel/contents",
            ],
            doesNotOwn: ["/repo/Models/Application.xcdatamodeld/contents"]
        )
    }

    func test_coreDataVersionsOutsideTheModelPackageDoNotCreateSeparateOwnership() throws {
        let target = Target.test(coreDataModels: [
            CoreDataModel(
                "/repo/Models/App.xcdatamodeld",
                versions: ["/repo/Legacy/V1.xcdatamodel"]
            ),
        ])

        try assertOwnership(target, doesNotOwn: ["/repo/Legacy/V1.xcdatamodel/contents"])
    }

    // MARK: - Headers

    func test_publicPrivateAndProjectHeadersUseTheSameIncludeSemantics() throws {
        let headers = Headers(
            public: .list(["/repo/Headers/Public.h", "/repo/Headers/Public/**/*.h"]),
            private: .glob("/repo/Headers/Private/**/*.h"),
            project: .glob("/repo/Headers/Project/**/*.h")
        )
        let target = Target.test(headers: .headers([headers]))

        try assertOwnership(
            target,
            owns: [
                "/repo/Headers/Public.h",
                "/repo/Headers/Public/Nested/Deleted.h",
                "/repo/Headers/Private/Internal.h",
                "/repo/Headers/Project/Support.h",
            ],
            doesNotOwn: ["/repo/Headers/Other.h"]
        )
    }

    func test_headerExclusionsAreScopedToTheirOwnList() throws {
        let publicHeaders = HeaderFileList.glob(
            "/repo/Headers/**/*.h",
            excluding: ["/repo/Headers/Generated/**"]
        )
        let target = Target.test(headers: .headers(public: publicHeaders))

        try assertOwnership(
            target,
            owns: ["/repo/Headers/Public.h"],
            doesNotOwn: ["/repo/Headers/Generated/Public.h"]
        )

        let projectHeaders = Headers(
            public: publicHeaders,
            project: .glob("/repo/Headers/Generated/**/*.h")
        )
        try assertOwnership(
            Target.test(headers: .headers([projectHeaders])),
            owns: ["/repo/Headers/Generated/Public.h"]
        )
    }

    func test_umbrellaHeaderAndFileModuleMapAreOwnedExactly() throws {
        let headers = Headers(
            umbrellaHeader: "/repo/Headers/Umbrella.h",
            moduleMap: .file(path: "/repo/Headers/module.modulemap")
        )
        let target = Target.test(headers: .headers([headers]))

        try assertOwnership(
            target,
            owns: ["/repo/Headers/Umbrella.h", "/repo/Headers/module.modulemap"],
            doesNotOwn: ["/repo/Headers/Umbrella.h/Child", "/repo/Headers/other.modulemap"]
        )
    }

    func test_generatedOrAbsentModuleMapsAndMappingsDirectoryAreNotOwned() throws {
        let generated = Headers(moduleMap: .generate, mappingsDir: "/repo/Headers/Mappings")
        let absent = Headers(moduleMap: .absent)
        let target = Target.test(headers: .headers([generated, absent]))

        try assertOwnership(
            target,
            doesNotOwn: ["/repo/Headers/module.modulemap", "/repo/Headers/Mappings/Header.h"]
        )
    }

    func test_copyFilesUseFileElementSemanticsWithoutReadingTheFilesystem() throws {
        let action = CopyFilesAction.resources(
            name: "Copy assets",
            files: [
                .file(path: "/repo/Assets/PrivacyInfo.xcprivacy"),
                .folderReference(path: "/repo/Assets/Templates"),
                .glob(pattern: "/repo/Assets/**/*.bundle"),
            ]
        )
        let target = Target.test(copyFiles: [action])

        try assertOwnership(
            target,
            owns: [
                "/repo/Assets/PrivacyInfo.xcprivacy",
                "/repo/Assets/Templates/Deleted.json",
                "/repo/Assets/Nested/SDK.bundle",
            ],
            doesNotOwn: [
                "/repo/Assets/PrivacyInfo.xcprivacy/Child",
                "/repo/Assets/SDK.framework",
            ]
        )
    }

    func test_targetIsReturnedOnlyOnceWhenSeveralDeclarationsOwnTheFile() throws {
        let file: AbsolutePath = "/repo/Shared.json"
        let target = Target.test(
            sources: [.glob(file)],
            resources: [.file(path: file)],
            additionalFiles: [.file(path: file)]
        )

        let result = try subject.resolve([file], graph: makeGraph(targets: [target]))

        XCTAssertEqual(result.first?.targets.map(\.target.name), [target.name])
    }

    func test_exclusionInSourcesDoesNotHideOwnershipThroughResources() throws {
        let file: AbsolutePath = "/repo/Generated/Config.json"
        let target = Target.test(
            sources: [.glob("/repo/**", excluding: ["/repo/Generated/**"])],
            resources: [.file(path: file)]
        )

        try assertOwnership(target, owns: [file])
    }

    func test_projectAdditionalFilesDoNotImplyTargetOwnership() throws {
        let target = Target.test()
        let project = Project.test(
            path: "/repo",
            targets: [target],
            additionalFiles: [.file(path: "/repo/README.md")]
        )
        let graph = makeGraph(projects: [project])

        let result = try subject.resolve(["/repo/README.md"], graph: graph)

        XCTAssertEqual(result.first?.targets, [])
    }

    // MARK: - Helpers

    private func assertOwnership(
        _ target: Target,
        owns ownedFiles: [AbsolutePath] = [],
        doesNotOwn unownedFiles: [AbsolutePath] = []
    ) throws {
        let files = ownedFiles + unownedFiles
        let result = try subject.resolve(files, graph: makeGraph(targets: [target]))
        let expectedTargets = ownedFiles.map { _ in [target.name] } + unownedFiles.map { _ in [] }

        XCTAssertEqual(result.map(\.file), files)
        XCTAssertEqual(
            result.map { $0.targets.map(\.target.name) },
            expectedTargets
        )
    }

    private func makeGraph(targets: [Target] = []) -> Graph {
        let project = Project.test(path: "/repo", sourceRootPath: "/repo", targets: targets)
        return makeGraph(projects: [project])
    }

    private func makeGraph(projects: [Project]) -> Graph {
        let projectsByPath = Dictionary(uniqueKeysWithValues: projects.map { ($0.path, $0) })
        let targetsByPath = Dictionary(uniqueKeysWithValues: projects.map { project in
            (project.path, Dictionary(uniqueKeysWithValues: project.targets.map { ($0.name, $0) }))
        })
        return .test(projects: projectsByPath, targets: targetsByPath)
    }
}
