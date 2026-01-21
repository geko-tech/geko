import Foundation
import GekoCore
import GekoGraph
import GekoSupportTesting
import ProjectDescription
import XCTest

@testable import GekoCocoapods

final class CocoapodsSpecInfoProviderTests: GekoUnitTestCase {
    func testCocoapodsGlob() throws {
        let spec = CocoapodsSpec.test(sourceFiles: [
            "Development/{TaigaUI,TaigaUIFoundation}/Tests/Unit/*.{swift,m}"
        ])
        let infoProvider = CocoapodsSpecInfoProvider(spec: spec)

        // When
        let result = infoProvider.sourceFiles().mapValues { $0.sorted() }

        XCTAssertEqual(
            result,
            [
                .default: [
                    "Development/{TaigaUI,TaigaUIFoundation}/Tests/Unit/*.{swift,m}"
                ]
            ]
        )
    }

    func testCocoapodsGlob_with_globstar() throws {
        let spec = CocoapodsSpec.test(sourceFiles: [
            "Development/TaigaUIFoundation/**/Tests/Unit/*.{swift,m}"
        ])
        let infoProvider = CocoapodsSpecInfoProvider(spec: spec)

        // When
        let result = infoProvider.sourceFiles().mapValues { $0.sorted() }

        XCTAssertEqual(
            result,
            [
                .default: [
                    "Development/TaigaUIFoundation/**/Tests/Unit/*.{swift,m}"
                ]
            ]
        )
    }

    func testGetDeploymentTargetIfEmpty() throws {
        // arrange
        let specSrc = """
            {
              "name": "Module",
              "summary": "A short description of Module.",
              "version": "5.2.0",
              "platforms": {
                "ios": "15.0"
              },
              "source_files": "A/A.swift",
              "testspecs": [
                {
                  "name": "UnitTests",
                  "test_type": "unit",
                  "source_files": [
                    "B/B.swift",
                  ],
                }
              ],
              "appspecs": [
                {
                  "name": "Example",
                  "source_files": "C/C.swift",
                }
              ],
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let testSpec = try XCTUnwrap(provider.testSpecs.first)
        let appSpec = try XCTUnwrap(provider.appSpecs.first)

        // act
        let testSpecTarget = testSpec.deploymentTargets(platform: .iOS)
        let appSpecTarget = appSpec.deploymentTargets(platform: .iOS)
        let testSpecDestinations = testSpec.destinations()
        let appSpecDestinations = appSpec.destinations()

        // assert
        XCTAssertEqual(testSpecTarget.iOS, "15.0")
        XCTAssertEqual(appSpecTarget.iOS, "15.0")
        XCTAssertEqual(appSpecDestinations, Destinations.iOS)
        XCTAssertEqual(testSpecDestinations, Destinations.iOS)
    }

    func testGetDeploymentTargetIfExist() throws {
        // arrange
        let specSrc = """
            {
              "name": "Module",
              "summary": "A short description of Module.",
              "version": "5.2.0",
              "platforms": {
                "ios": "15.0",
                "tvos": "17.0"
              },
              "source_files": "A/A.swift",
              "testspecs": [
                {
                  "name": "UnitTests",
                  "test_type": "unit",
                  "platforms": {
                    "ios": "17.0",
                  },
                  "source_files": [
                    "B/B.swift",
                  ],
                }
              ],
              "appspecs": [
                {
                  "name": "Example",
                  "platforms": {
                    "ios": "18.0"
                  },
                  "source_files": "C/C.swift",
                }
              ],
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let testSpec = try XCTUnwrap(provider.testSpecs.first)
        let appSpec = try XCTUnwrap(provider.appSpecs.first)

        // act
        let testSpecTarget = testSpec.deploymentTargets(platform: .iOS)
        let appSpecTarget = appSpec.deploymentTargets(platform: .iOS)
        let specDestinations = provider.destinations()
        let testSpecDestinations = testSpec.destinations()

        // assert
        XCTAssertEqual(testSpecTarget.iOS, "17.0")
        XCTAssertEqual(appSpecTarget.iOS, "18.0")
        XCTAssertEqual(specDestinations, Destinations.iOS.union(Destinations.tvOS))
        XCTAssertEqual(testSpecDestinations, Destinations.iOS)
    }

    func testProviderReturnsSourcesFromSubspecs() throws {
        // arrange
        let spec: CocoapodsSpec = CocoapodsSpec.test(
            name: "TestSpec",
            sourceFiles: ["TestSpec/Sources/**/*"],
            subspecs: [
                .test(name: "SubSpec1", sourceFiles: ["SubSpec1/Sources/**/*"]),
                .test(name: "SubSpec2", sourceFiles: ["SubSpec2/Sources/**/*"]),
                .test(name: "SubSpec3", sourceFiles: ["SubSpec3/Sources/**/*"]),
            ]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec, subspecs: ["SubSpec1", "SubSpec2"])

        // act
        let result = provider.sourceFiles()

        // assert
        let expected: [CocoapodsPlatform: Set<String>] = [
            .default: [
                "TestSpec/Sources/**/*",
                "SubSpec1/Sources/**/*",
                "SubSpec2/Sources/**/*",
            ]
        ]
        XCTAssertEqual(result, expected)
    }
}
