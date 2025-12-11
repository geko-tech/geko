import Foundation
import GekoSupportTesting
import XCTest

@testable import ProjectDescription

final class TargetTests: XCTestCase {
    func test_codable_defaultValues() {
        // Given
        let subject = Target(
            name: "Test",
            destinations: .iOS,
            product: .staticLibrary
        )

        // Then
        XCTAssertCodable(subject)
    }

    func test_codable_customValues() {
        // Given
        let subject = ProjectDescription.Target(
            name: "Unit-Test",
            destinations: .macOS,
            product: .staticLibrary,
            productName: "product_name",
            bundleId: "io.geko.library",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .file(path: "file/path"),
            buildableFolders: ["buildable/folder"],
            sources: [SourceFiles(glob: "files/*.swift")],
            playgrounds: ["playground/path"],
            resources: [.file(path: "file/path")],
            copyFiles: [.productsDirectory(name: "name", files: ["file/path"])],
            headers: .headers(public: "files/*.h"),
            entitlements: .file(path: "file/path"),
            scripts: [.pre(script: "echo hello", name: "script")],
            dependencies: [.target(name: "TargetDep")],
            ignoreDependencies: [.target(name: "TargetDep")],
            prioritizeDependencies: [.target(name: "TargetDep")],
            settings: .settings(),
            coreDataModels: [.init("file/path")],
            environmentVariables: ["env": "value"],
            launchArguments: [.init(name: "name", isEnabled: true)],
            additionalFiles: ["additional/file"],
            preCreatedFiles: ["preCreated/file"],
            buildRules: [.init(name: "rule", fileType: .nasmAssembly, compilerSpec: .nasm)],
            mergedBinaryType: .disabled,
            mergeable: true,
            filesGroup: .group(name: "Project")
        )

        // Then
        XCTAssertCodable(subject)
    }

    func test_encode_outputsOnlyNecessaryFields() throws {
        // Given
        let subject = Target(
            name: "Test",
            destinations: [.iPhone],
            product: .staticLibrary,
            infoPlist: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // When
        let data = try encoder.encode(subject)
        let result = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Then
        XCTAssertEqual(
            result,
            """
            {
              "destinations" : [
                "iPhone"
              ],
              "filesGroup" : {
                "group" : {
                  "name" : "Project"
                }
              },
              "mergeable" : false,
              "mergedBinaryType" : {
                "disabled" : {

                }
              },
              "name" : "Test",
              "product" : "static_library",
              "productName" : "Test",
              "prune" : false
            }
            """
        )
    }

    func test_decode_parsesEmptyOptionalFields() throws {
        // Given
        let json = 
            """
            {
              "destinations" : [
                "iPhone"
              ],
              "filesGroup" : {
                "group" : {
                  "name" : "Project"
                }
              },
              "mergeable" : false,
              "mergedBinaryType" : {
                "disabled" : {

                }
              },
              "name" : "Test",
              "product" : "static_library",
              "productName" : "Test"
            }
            """

        let decoder = JSONDecoder()


        // When
        let result = try decoder.decode(Target.self, from: XCTUnwrap(json.data(using: .utf8)))

        // Then
        XCTAssertEqual(
            result,
            Target(
                name: "Test",
                destinations: [.iPhone],
                product: .staticLibrary,
                infoPlist: nil
            )
        )
    }

    func test_toJSON() {
        let subject = Target(
            name: "name",
            destinations: .iOS,
            product: .app,
            productName: "product_name",
            bundleId: "bundle_id",
            deploymentTargets: .iOS("13.1"),
            infoPlist: "info.plist",
            buildableFolders: [BuildableFolder("path", exceptions: [])],
            sources: ["sources/*"],
            resources: ["resources/*"],
            headers:  .headers(
                public: "public/*",
                private: "private/*",
                project: "project/*"
            ),
            entitlements: "entitlement",
            scripts: [
                TargetScript.post(path: "path", arguments: ["arg"], name: "name"),
            ],
            dependencies: [
                .framework(path: "path"),
                .library(path: "path", publicHeaders: "public", swiftModuleMap: "module"),
                .project(target: "target", path: "path"),
                .target(name: "name"),
            ],
            settings: .settings(
                base: ["a": .string("b")],
                debug: ["a": .string("b")],
                release: ["a": .string("b")]
            ),
            coreDataModels: [CoreDataModel("pat", currentVersion: "version")],
            environmentVariables: ["a": "b"]
        )
        XCTAssertCodable(subject)
    }

    func test_toJSON_withFileList() {
        let subject = Target(
            name: "name",
            destinations: .iOS,
            product: .app,
            productName: "product_name",
            bundleId: "bundle_id",
            deploymentTargets: .iOS("13.1"),
            infoPlist: "info.plist",
            buildableFolders: [BuildableFolder("path", exceptions: [])],
            sources: [
                "sources/*",
                .glob("Intents/Public.intentdefinition", codeGen: .public),
                .glob("Intents/Private.intentdefinition", codeGen: .private),
                .glob("Intents/Project.intentdefinition", codeGen: .project),
                .glob("Intents/Disabled.intentdefinition", codeGen: .disabled),
            ],
            resources: [
                "resources/*",
                .glob(pattern: "file.type", tags: ["tag"]),
                .folderReference(path: "resource/", tags: ["tag"]),
            ],
            headers: .headers(
                public: ["public/*"],
                private: ["private/*"],
                project: ["project/*"]
            ),
            entitlements: "entitlement",
            scripts: [
                TargetScript.post(path: "path", arguments: ["arg"], name: "name"),
            ],
            dependencies: [
                .framework(path: "path"),
                .library(path: "path", publicHeaders: "public", swiftModuleMap: "module"),
                .project(target: "target", path: "path"),
                .target(name: "name"),
            ],
            settings: .settings(
                base: ["a": .string("b")],
                configurations: [
                    .debug(name: .debug, settings: ["a": .string("debug")], xcconfig: "debug.xcconfig"),
                    .debug(name: "Beta", settings: ["a": .string("beta")], xcconfig: "beta.xcconfig"),
                    .debug(name: .release, settings: ["a": .string("release")], xcconfig: "debug.xcconfig"),
                ]
            ),
            coreDataModels: [CoreDataModel("pat", currentVersion: "version")],
            environmentVariables: ["a": "b"]
        )
        XCTAssertCodable(subject)
    }
}
