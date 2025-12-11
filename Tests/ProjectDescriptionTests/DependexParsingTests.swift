import XCTest

@testable import ProjectDescription

final class DependexParsingTests: XCTestCase {
    func test_project_parsing() throws {
        let project = ProjectDescription.Project(
            name: "TestProject",
            targets: [
                Target(
                    name: "TestTargetApp",
                    destinations: .iOS,
                    product: .app
                ),
                Target(
                    name: "TestTargetStaticLibrary",
                    destinations: .iOS,
                    product: .staticLibrary
                ),
                Target(
                    name: "TestTargetDynamicLibrary",
                    destinations: .iOS,
                    product: .dynamicLibrary
                ),
                Target(
                    name: "TestTargetFramework",
                    destinations: .iOS,
                    product: .framework
                ),
                Target(
                    name: "TestTargetStaticFramework",
                    destinations: .iOS,
                    product: .staticFramework
                ),
                Target(
                    name: "TestTargetUnitTests",
                    destinations: .iOS,
                    product: .uiTests
                ),
                Target(
                    name: "TestTargetBundle",
                    destinations: .iOS,
                    product: .bundle
                ),
                Target(
                    name: "TestTargetCLI",
                    destinations: .iOS,
                    product: .commandLineTool
                ),
                Target(
                    name: "TestTargetAppClip",
                    destinations: .iOS,
                    product: .appClip
                ),
                Target(
                    name: "TestTargetAppExtension",
                    destinations: .iOS,
                    product: .appExtension
                ),
                Target(
                    name: "TestTargetWatch2App",
                    destinations: .iOS,
                    product: .watch2App
                ),
                Target(
                    name: "TestTargetWatch2Extension",
                    destinations: .iOS,
                    product: .watch2Extension
                ),
                Target(
                    name: "TestTargetTVTopShelfExtesion",
                    destinations: .iOS,
                    product: .tvTopShelfExtension
                ),
                Target(
                    name: "TestTargetMessagesExtension",
                    destinations: .iOS,
                    product: .messagesExtension
                ),
                Target(
                    name: "TestTargetStickerPackExtension",
                    destinations: .iOS,
                    product: .stickerPackExtension
                ),
                Target(
                    name: "TestTargetXCP",
                    destinations: .iOS,
                    product: .xpc
                ),
                Target(
                    name: "TestTargetSystemExtension",
                    destinations: .iOS,
                    product: .systemExtension
                ),
                Target(
                    name: "TestTargetExtensionKitExtension",
                    destinations: .iOS,
                    product: .extensionKitExtension
                ),
                Target(
                    name: "TestTargetMacro",
                    destinations: .iOS,
                    product: .macro
                ),
                Target(
                    name: "TestTargetAggregateTarget",
                    destinations: .iOS,
                    product: .aggregateTarget
                ),
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(project)

        enum RawProduct: String, Decodable, Equatable {
            case app = "app"
            case staticLibrary = "static_library"
            case dynamicLibrary = "dynamic_library"
            case framework = "framework"
            case staticFramework = "staticFramework"
            case unitTests = "unit_tests"
            case uiTests = "ui_tests"
            case bundle = "bundle"
            case commandLineTool = "commandLineTool"
            case appClip = "appClip"
            case appExtension = "app_extension"
            case watch2App = "watch2App"
            case watch2Extension = "watch2Extension"
            case tvTopShelfExtension = "tvTopShelfExtension"
            case messagesExtension = "messagesExtension"
            case stickerPackExtension = "sticker_pack_extension"
            case xpc = "xpc"
            case systemExtension = "systemExtension"
            case extensionKitExtension = "extension_kit_extension"
            case macro = "macro"
            case aggregateTarget = "aggregate_target"
        }

        struct RawTarget: Decodable, Equatable {
            let name: String
            let product: RawProduct
        }

        struct RawProject: Decodable, Equatable {
            let name: String
            let targets: [RawTarget]
        }

        let decoder = JSONDecoder()
        let rawProject = try decoder.decode(RawProject.self, from: data)

        XCTAssertEqual(
            RawProject(
                name: "TestProject",
                targets: [
                    RawTarget(
                        name: "TestTargetApp",
                        product: .app
                    ),
                    RawTarget(
                        name: "TestTargetStaticLibrary",
                        product: .staticLibrary
                    ),
                    RawTarget(
                        name: "TestTargetDynamicLibrary",
                        product: .dynamicLibrary
                    ),
                    RawTarget(
                        name: "TestTargetFramework",
                        product: .framework
                    ),
                    RawTarget(
                        name: "TestTargetStaticFramework",
                        product: .staticFramework
                    ),
                    RawTarget(
                        name: "TestTargetUnitTests",
                        product: .uiTests
                    ),
                    RawTarget(
                        name: "TestTargetBundle",
                        product: .bundle
                    ),
                    RawTarget(
                        name: "TestTargetCLI",
                        product: .commandLineTool
                    ),
                    RawTarget(
                        name: "TestTargetAppClip",
                        product: .appClip
                    ),
                    RawTarget(
                        name: "TestTargetAppExtension",
                        product: .appExtension
                    ),
                    RawTarget(
                        name: "TestTargetWatch2App",
                        product: .watch2App
                    ),
                    RawTarget(
                        name: "TestTargetWatch2Extension",
                        product: .watch2Extension
                    ),
                    RawTarget(
                        name: "TestTargetTVTopShelfExtesion",
                        product: .tvTopShelfExtension
                    ),
                    RawTarget(
                        name: "TestTargetMessagesExtension",
                        product: .messagesExtension
                    ),
                    RawTarget(
                        name: "TestTargetStickerPackExtension",
                        product: .stickerPackExtension
                    ),
                    RawTarget(
                        name: "TestTargetXCP",
                        product: .xpc
                    ),
                    RawTarget(
                        name: "TestTargetSystemExtension",
                        product: .systemExtension
                    ),
                    RawTarget(
                        name: "TestTargetExtensionKitExtension",
                        product: .extensionKitExtension
                    ),
                    RawTarget(
                        name: "TestTargetMacro",
                        product: .macro
                    ),
                    RawTarget(
                        name: "TestTargetAggregateTarget",
                        product: .aggregateTarget
                    ),
                ]
            ),
            rawProject
        )
    }

    func test_dependency_parsing() throws {
        let target = ProjectDescription.Target(
            name: "TestTarget",
            destinations: .iOS,
            product: .app,
            dependencies: [
                .target(name: "Target"),
                .local(name: "Local"),
                .project(target: "Project", path: .relativeToRoot("Project")),
                .framework(path: .relativeToRoot("Framework")),
                .library(path: .relativeToRoot("Library"), publicHeaders: .relativeToRoot("Library"), swiftModuleMap: nil),
                .sdk(name: "SDK", type: .framework),
                .xcframework(path: .relativeToRoot("XCFramework")),
                .bundle(path: .relativeToRoot("Bundle")),
                .xctest,
                .external(name: "External"),
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(target)

        struct NameDependency: Decodable, Equatable {
            let name: String
        }

        typealias RawTargetDependency = NameDependency
        typealias RawLocalDependency = NameDependency
        typealias RawExternalDependency = NameDependency

        struct RawProjectDependency: Decodable, Equatable {
            let target: String
            let path: RawPath
        }

        typealias RawPath = String

        struct RawPathDependency: Decodable, Equatable {
            let path: RawPath
        }

        typealias RawFrameworkDependency = RawPathDependency
        typealias RawLibraryDependency = RawPathDependency
        typealias RawXCFrameworkDependency = RawPathDependency
        typealias RawBundleDependency = RawPathDependency

        struct RawPackageDependency: Decodable, Equatable {
            let product: String
        }

        struct RawSDKDependency: Decodable, Equatable {
            let name: String
            let type: String
        }

        struct RawXCTestDependency: Decodable, Equatable {}

        struct RawDependency: Decodable, Equatable {
            let target: RawTargetDependency?
            let local: RawLocalDependency?
            let project: RawProjectDependency?
            let framework: RawFrameworkDependency?
            let library: RawLibraryDependency?
            let package: RawPackageDependency?
            let sdk: RawSDKDependency?
            let xcframework: RawXCFrameworkDependency?
            let bundle: RawBundleDependency?
            let xctest: RawXCTestDependency?
            let external: RawExternalDependency?

            init(
                target: RawTargetDependency? = nil,
                local: RawLocalDependency? = nil,
                project: RawProjectDependency? = nil,
                framework: RawFrameworkDependency? = nil,
                library: RawLibraryDependency? = nil,
                package: RawPackageDependency? = nil,
                sdk: RawSDKDependency? = nil,
                xcframework: RawXCFrameworkDependency? = nil,
                bundle: RawBundleDependency? = nil,
                xctest: RawXCTestDependency? = nil,
                external: RawExternalDependency? = nil
            ) {
                self.target = target
                self.local = local
                self.project = project
                self.framework = framework
                self.library = library
                self.package = package
                self.sdk = sdk
                self.xcframework = xcframework
                self.bundle = bundle
                self.xctest = xctest
                self.external = external
            }
        }

        struct RawTarget: Decodable, Equatable {
            let dependencies: [RawDependency]
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(RawTarget.self, from: data)

        XCTAssertEqual(result.dependencies[0], RawDependency(target: .init(name: "Target")))
        XCTAssertEqual(result.dependencies[1], RawDependency(local: .init(name: "Local")))
        XCTAssertEqual(result.dependencies[2], RawDependency(project: .init(target: "Project", path: "@/Project")))
        XCTAssertEqual(result.dependencies[3], RawDependency(framework: .init(path: "@/Framework")))
        XCTAssertEqual(result.dependencies[4], RawDependency(library: .init(path: "@/Library")))
        XCTAssertEqual(result.dependencies[5], RawDependency(sdk: .init(name: "SDK", type: "framework")))
        XCTAssertEqual(result.dependencies[6], RawDependency(xcframework: .init(path: "@/XCFramework")))
        XCTAssertEqual(result.dependencies[7], RawDependency(bundle: .init(path: "@/Bundle")))
        XCTAssertEqual(result.dependencies[8], RawDependency(xctest: .init()))
        XCTAssertEqual(result.dependencies[9], RawDependency(external: .init(name: "External")))
    }
}
