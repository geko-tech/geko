import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoSupport
import GekoSupportTesting
import XCTest

@testable import GekoCocoapods

final class CocoapodsTargetGeneratorTests: GekoUnitTestCase {
    func testNativeTargetGenerationWithExcludeFiles() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: ["Sources/**/*.swift"],
            excludeFiles: [
                "Sources/Exclude/**/*.swift",
                "Sources/B/File1.swift",
            ],
            moduleMap: CocoapodsSpec.ModuleMap.none
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        let expectedSources = [
            SourceFiles.glob(
                "Sources/**/*.swift",
                excluding: [
                    "Sources/B/File1.swift",
                    "Sources/Exclude/**/*.swift",
                ]
            )
        ]

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        XCTAssertEqual(sideEffects.count, 0)

        var target = try XCTUnwrap(targets.first)
        for globIdx in 0..<target.sources.count {
            target.sources[globIdx].excluding.sort {
                $0.pathString < $1.pathString
            }
            target.sources[globIdx].paths.sort {
                $0.pathString < $1.pathString
            }
        }

        XCTAssertEqual(target.sources, expectedSources)
    }

    func testNativeTargetGenerationWithHeadersInSourceFiles() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: ["Sources/**/*.{swift,c,h}"],
            moduleMap: CocoapodsSpec.ModuleMap.none
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        _ = try createFiles([
            "Sources/File1.swift",
            "Sources/File2.swift",
            "Sources/A/File3.swift",
            "Sources/A/File4.swift",
            "Sources/B/File5.h",
            "Sources/B/File6.c",
            "Sources/C/File7.h",
        ])
        let expectedSources = [
            SourceFiles.glob("Sources/**/*.{swift,c,h}"),
        ]

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        XCTAssertEqual(sideEffects.count, 0)

        var target = try XCTUnwrap(targets.first)
        target.sources.sort {
            $0.paths[0].pathString < $1.paths[0].pathString
        }
        for globIdx in 0..<target.sources.count {
            target.sources[globIdx].excluding.sort {
                $0.pathString < $1.pathString
            }
            target.sources[globIdx].paths.sort {
                $0.pathString < $1.pathString
            }
        }

        XCTAssertEqual(target.sources, expectedSources)
    }

    func testSourcesEmptyIfSpecContainsOnlyHeaders() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: ["Sources/**/*.{swift,c,h}"],
            moduleMap: CocoapodsSpec.ModuleMap.none
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        _ = try createFiles([
            "Sources/B/File5.h",
            "Sources/C/File7.h",
        ])

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        XCTAssertEqual(sideEffects.count, 0)

        let target = try XCTUnwrap(targets.first)

        XCTAssertEqual(target.sources, [SourceFiles.glob("Sources/**/*.{swift,c,h}")])
    }

    func testResourcesDoNotIncludePrecompiledBundles() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            moduleMap: CocoapodsSpec.ModuleMap.none,
            resources: [
                "Resources/**/*.json",
                "Resources/Settings.bundle",
                "Resources/Images.bundle",
            ]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        let expectedResources = [
            ResourceFileElement.glob(pattern: "Resources/**/*.json")
        ]

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        // by logic of cocoapods target without sources but with resources is considered a static framework
        XCTAssertEqual(targets.first?.product, .staticFramework)
        XCTAssertEqual(sideEffects.count, 0)

        let target = try XCTUnwrap(targets.first)

        XCTAssertEqual(target.resources, expectedResources)
    }

    func testResourceBundles() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            moduleMap: CocoapodsSpec.ModuleMap.none,
            resourceBundles: [
                "NativeTargetBundle": [
                    "Resources/**/*"
                ]
            ]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        // let path = try temporaryPath()
        let path = try AbsolutePath(validating: "/path")
        let expectedResources = [
            ResourceFileElement.glob(
                pattern: "Resources/**/*"
            )
        ]

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEmpty(sideEffects)

        let bundleTarget = try XCTUnwrap(targets.first)

        XCTAssertEqual(bundleTarget.product, .bundle)
        XCTAssertEqual(bundleTarget.resources, expectedResources)
    }

    func testImplicitPublicHeaders() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: [
                "Sources/**/*.{swift,c,h}",
                "Headers/**/*.{swift,c,h}",
            ],
            privateHeaderFiles: [
                "Headers/Private/**/*.h"
            ],
            projectHeaderFiles: [
                "Headers/Project/**/*.h"
            ],
            headerMappingsDir: "Headers",
            moduleMap: CocoapodsSpec.ModuleMap.none,
            resources: [
                "Resources/**/*.json",
                "Resources/Settings.bundle",
                "Resources/Images.bundle",
            ]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        _ = try createFiles([
            "Sources/B/Source.swift",
            "Headers/Public/Header.h",
            "Headers/Public/A/Header.h",
            "Headers/Private/Header.h",
            "Headers/Project/Header.h",
        ])
        let expectedHeaders = ProjectDescription.Headers.headers(
            public: nil,
            private: "Headers/Private/**/*.h",
            project: "Headers/Project/**/*.h",
            mappingsDir: "Headers"
        )

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(sideEffects.count, 0)

        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.headers?.list.count, 1)
        var headers = try XCTUnwrap(target.headers?.list.first)
        headers.public?.files.sort { $0.pathString < $1.pathString }
        headers.project?.files.sort { $0.pathString < $1.pathString }

        XCTAssertEqual(headers.public, expectedHeaders.public)
        XCTAssertEqual(headers.private, expectedHeaders.private)
        XCTAssertEqual(headers.project, expectedHeaders.project)
        XCTAssertEqual(headers.mappingsDir, expectedHeaders.mappingsDir)
        XCTAssertEqual(headers.exclusionRule, .publicExcludesPrivateAndProject)
    }

    func testExplicitPublicHeaders() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: [
                "Sources/**/*.{swift,c,h}",
                "Headers/**/*.{swift,c,h}",
            ],
            publicHeaderFiles: [
                "Headers/Public/**/*.h"
            ],
            privateHeaderFiles: [
                "Headers/Private/**/*.h"
            ],
            projectHeaderFiles: [
                "Headers/Project/**/*.h"
            ],
            headerMappingsDir: "Headers",
            moduleMap: CocoapodsSpec.ModuleMap.none,
            resources: [
                "Resources/**/*.json",
                "Resources/Settings.bundle",
                "Resources/Images.bundle",
            ]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        let expectedHeaders = ProjectDescription.Headers.headers(
            public: "Headers/Public/**/*.h",
            private: "Headers/Private/**/*.h",
            project: "Headers/Project/**/*.h",
            mappingsDir: "Headers"
        )

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(sideEffects.count, 0)

        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.headers?.list.count, 1)
        var headers = try XCTUnwrap(target.headers?.list.first)
        headers.public?.files.sort { $0.pathString < $1.pathString }
        headers.project?.files.sort { $0.pathString < $1.pathString }

        XCTAssertEqual(headers.public, expectedHeaders.public)
        XCTAssertEqual(headers.private, expectedHeaders.private)
        XCTAssertEqual(headers.project, expectedHeaders.project)
        XCTAssertEqual(headers.mappingsDir, expectedHeaders.mappingsDir)
        XCTAssertEqual(headers.exclusionRule, .projectExcludesPrivateAndPublic)
    }

    func testUmbrellaHeaderAbsentWhenModuleMapDisabled() throws {
        let specSrc = """
            {
              "name": "RKOAccount",
              "version": "0.1.0",
              "summary": "RKOAccount",
              "platforms": {
                "ios": "15.0"
              },
              "source_files": "Sources/File.swift",
              "module_map": false
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles(["Sources/File.swift"])
        let (targets, sideEffects) = try g.nativeTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: "/Unused",
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        let headers = try XCTUnwrap(targets.first?.headers)
        XCTAssertNotEmpty(headers.list)
        XCTAssertEqual(headers.list, [
            Headers(
                moduleMap: .absent,
                exclusionRule: .publicExcludesPrivateAndProject,
                compilationCondition: nil
            ),
            Headers(
                moduleMap: .absent,
                exclusionRule: .publicExcludesPrivateAndProject,
                compilationCondition: .when([.ios])
            ),
        ])
        XCTAssertEmpty(sideEffects)
    }

    func testModuleMapPresentByDefault() throws {
        let specSrc = """
            {
              "name": "RKOAccount",
              "version": "0.1.0",
              "summary": "RKOAccount",
              "platforms": {
                "ios": "15.0"
              },
              "source_files": "Sources/File.swift"
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles(["Sources/File.swift"])
        let moduleMapDir = try temporaryPath().appending(component: "ModuleMap")
        let (targets, sideEffects) = try g.nativeTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: moduleMapDir,
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)

        let headers = try XCTUnwrap(targets.first?.headers?.list)
        XCTAssertEqual(headers, [
            Headers(
                moduleMap: .generate,
                exclusionRule: .publicExcludesPrivateAndProject,
                compilationCondition: nil
            ),
            Headers(
                moduleMap: .generate,
                exclusionRule: .publicExcludesPrivateAndProject,
                compilationCondition: .when([.ios])
            ),
        ])

        XCTAssertEqual(sideEffects.count, 0)
    }

    func testUmbrellaHeaderAndModuleMapDefaultMixedMultiplatformModule() throws {
        let specSrc = """
            {
              "name": "HeadersObjcPod",
              "version": "0.1.0",
              "summary": "HeadersObjcPod",
              "platforms": {
                "ios": "15.0",
                "tvos": "15.0"
              },
              "source_files": [
                "Sources/Common/File.swift",
                "Sources/Common/MyLoggerCommon.h",
                "Sources/Common/MyLoggerCommon.m"
              ],
              "ios": {
                "source_files": [
                    "Sources/iOS/FileiOS.swift",
                    "Sources/iOS/MyLoggeriOS.h",
                    "Sources/iOS/MyLoggeriOS.m"
                ]
              },
              "tvos": {
                "source_files": [
                    "Sources/tvOS/FiletvOS.swift",
                    "Sources/tvOS/MyLoggertvOS.h",
                    "Sources/tvOS/MyLoggertvOS.m"
                ]
              }
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles([
            "Sources/Common/File.swift",
            "Sources/Common/MyLoggerCommon.h",
            "Sources/Common/MyLoggerCommon.m",
            "Sources/iOS/FileiOS.swift",
            "Sources/iOS/MyLoggeriOS.h",
            "Sources/iOS/MyLoggeriOS.m",
            "Sources/tvOS/FiletvOS.swift",
            "Sources/tvOS/MyLoggertvOS.h",
            "Sources/tvOS/MyLoggertvOS.m"
        ])

        let moduleMapDir = try temporaryPath().appending(component: "ModuleMap")
        let (targets, _) = try g.nativeTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: moduleMapDir,
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        let target = try XCTUnwrap(targets.first)
        let commonSourceFiles = target.sources.filter({ $0.compilationCondition == nil }).flatMap { $0.paths }
        let iOSSourceFiles = target.sources.filter({ $0.compilationCondition == .when([.ios]) }).flatMap { $0.paths }
        let tvOSSourceFiles = target.sources.filter({ $0.compilationCondition == .when([.tvos]) }).flatMap { $0.paths }
        
        // Expected Sources
        
        let commonSourceFileExpcted = [
            "Sources/Common/File.swift", "Sources/Common/MyLoggerCommon.m", "Sources/Common/MyLoggerCommon.h"
        ]
        let iosSourceFileExpcted = [
            "Sources/iOS/FileiOS.swift", "Sources/iOS/MyLoggeriOS.m", "Sources/iOS/MyLoggeriOS.h"
        ]
        let tvosSourceFileExpcted = [
            "Sources/tvOS/FiletvOS.swift", "Sources/tvOS/MyLoggertvOS.m", "Sources/tvOS/MyLoggertvOS.h"
        ]

        // Then (Check source files filter)

        XCTAssertEqual(commonSourceFiles.map { $0.pathString }.sorted(), commonSourceFileExpcted.sorted())
        XCTAssertEqual(iOSSourceFiles.map { $0.pathString }.sorted(), iosSourceFileExpcted.sorted())
        XCTAssertEqual(tvOSSourceFiles.map { $0.pathString }.sorted(), tvosSourceFileExpcted.sorted())
        
        // Then (Check headers)
        
        let headers = try XCTUnwrap(target.headers)
        XCTAssertEqual(headers.list.count, 3) // default, ios, tvos

        let expectedHeaders = HeadersList(list: [
            Headers(moduleMap: .generate, exclusionRule: .publicExcludesPrivateAndProject),
            Headers(moduleMap: .generate, exclusionRule: .publicExcludesPrivateAndProject, compilationCondition: .when([.ios])),
            Headers(moduleMap: .generate, exclusionRule: .publicExcludesPrivateAndProject, compilationCondition: .when([.tvos])),
        ])
        XCTAssertEqual(headers, expectedHeaders)
    }

    func testUmbrellaHeaderAndModuleMapDefaultMixedNoPlatformModule() throws {
        let specSrc = """
            {
              "name": "MixedModule",
              "version": "0.1.0",
              "summary": "HeadersObjcPod",
              "source_files": [
                "Sources/Common/File.swift",
                "Sources/Common/MyLoggerCommon.h",
                "Sources/Common/MyLoggerCommon.m"
              ]
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles([
            "Sources/Common/File.swift",
            "Sources/Common/MyLoggerCommon.h",
            "Sources/Common/MyLoggerCommon.m"
        ])

        let moduleMapDir = try temporaryPath().appending(component: "ModuleMap")
        let (targets, sideEffects) = try g.nativeTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: moduleMapDir,
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.headers?.list.count, 1) // default

        XCTAssertEqual(target.headers, HeadersList(list: [
            Headers(moduleMap: .generate, exclusionRule: .publicExcludesPrivateAndProject)
        ]))

        XCTAssertEqual(sideEffects.count, 0)
    }

    func testUmbrellaHeaderAndModuleMapExplicitModuleMapModule() throws {
        let specSrc = """
            {
              "name": "HeadersObjcPod",
              "version": "0.1.0",
              "summary": "HeadersObjcPod",
              "platforms": {
                "ios": "15.0",
                "tvos": "15.0"
              },
              "source_files": [
                "Sources/Common/File.swift"
              ],
              "ios": {
                "source_files": [
                    "Sources/iOS/FileiOS.swift",
                    "Sources/iOS/MyLoggeriOS.h",
                    "Sources/iOS/MyLoggeriOS.m"
                ],
                "public_header_files": [
                    "Sources/iOS/HeadersPod-Umbrella-IOS.h",
                    "Sources/iOS/MyLoggeriOS.h"
                ],
                "module_map": "Sources/iOS/module.modulemap"
              },
              "tvos": {
                "source_files": [
                    "Sources/tvOS/FiletvOS.swift",
                    "Sources/tvOS/MyLoggertvOS.h",
                    "Sources/tvOS/MyLoggertvOS.m"
                ],
                "public_header_files": [
                    "Sources/tvOS/HeadersPod-Umbrella-tvOS.h",
                    "Sources/tvOS/MyLoggertvOS.h"
                ],
                "module_map": "Sources/tvOS/module.modulemap"
              }
            }
            """.data(using: .utf8)
        
        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles([
            "Sources/Common/File.swift",
            "Sources/iOS/FileiOS.swift",
            "Sources/iOS/MyLoggeriOS.h",
            "Sources/iOS/MyLoggeriOS.m",
            "Sources/iOS/HeadersPod-Umbrella-IOS.h",
            "Sources/tvOS/FiletvOS.swift",
            "Sources/tvOS/MyLoggertvOS.h",
            "Sources/tvOS/MyLoggertvOS.m",
            "Sources/tvOS/HeadersPod-Umbrella-tvOS.h"
        ])
        
        let moduleMapDir = try temporaryPath().appending(component: "ModuleMap")
        let (targets, sideEffects) = try g.nativeTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: moduleMapDir,
            appHostDir: "/Unused",
            buildableFolderInference: false
        )
        
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.headers?.list.count, 3) // default, tvos, ios
        XCTAssertEqual(sideEffects.count, 0)
    }

    func testResourcesFolderReference() throws {
        let specSrc = """
            {
              "name": "RKOAccount",
              "version": "0.1.0",
              "summary": "RKOAccount",
              "platforms": {
                "ios": "15.0"
              },
              "source_files": "Sources/File.swift",
              "resources": [
                "Resources/Stubs",
                "Resources/{A,B,Assets.xcassets}",
                "Resources/*.lproj/**"
              ]
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles(
            [
                "Resources/Stubs/a/1.json",
                "Resources/Stubs/b/2.json",
                "Resources/Stubs/c/3.json",
                "Resources/A/.keep",
                "Resources/B/.keep",
                "Resources/ru.lproj/**",
                "Resources/Assets.xcassets/.keep",
            ]
        )

        let tmp = try temporaryPath()

        let (targets, _) = try g.nativeTargets(
            for: provider,
            path: tmp,
            moduleMapDir: "/Unused",
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        let resources = try XCTUnwrap(targets.first?.resources)

        XCTAssertEqual(
            resources,
            [
                .glob(pattern: "Resources/*.lproj/**"),
                .folderReference(path: "Resources/Stubs"),
                .glob(pattern: "Resources/{A,B,Assets.xcassets}"),
            ]
        )
    }

    func testResourceBundleFolderReference() throws {
        let specSrc = """
            {
              "name": "RKOAccount",
              "version": "0.1.0",
              "summary": "RKOAccount",
              "platforms": {
                "ios": "15.0"
              },
              "source_files": "Sources/File.swift",
              "resource_bundles": {
                "Resources": [
                    "Resources/Stubs",
                    "Resources/{A,B,Assets.xcassets}",
                    "Resources/*.lproj/**"
                ]
              }
            }
            """.data(using: .utf8)

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)
        try createFiles(
            [
                "Resources/Stubs/a/1.json",
                "Resources/Stubs/b/2.json",
                "Resources/Stubs/c/3.json",
                "Resources/A/.keep",
                "Resources/B/.keep",
                "Resources/ru.lproj/**",
                "Resources/Assets.xcassets/.keep",
            ]
        )

        let tmp = try temporaryPath()

        let (targets, _) = try g.nativeTargets(
            for: provider,
            path: tmp,
            moduleMapDir: "/Unused",
            appHostDir: "/Unused",
            buildableFolderInference: false
        )

        let resources = try XCTUnwrap(targets.first?.resources)

        let expectedResources: [ResourceFileElement] = [
            .glob(pattern: "Resources/*.lproj/**"),
            .folderReference(path: "Resources/Stubs"),
            .glob(pattern: "Resources/{A,B,Assets.xcassets}"),
        ]

        XCTAssertEqual(resources, expectedResources)
    }

    func testBuildableFolderInference() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: [
                "Sources/ShouldBeInferred/**/*",
            ],
            moduleMap: CocoapodsSpec.ModuleMap.none
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        _ = try createFiles([
            "Sources/ShouldBeInferred/File1.swift",
            "Sources/ShouldBeInferred/File2.swift",
            "Sources/ShouldNotBeInferred/File3.swift",
            "Sources/ShouldNotBeInferred2/File3.swift",
        ])
        let expectedBuildableFolders: [BuildableFolder] = [
            BuildableFolder(
                "Sources/ShouldBeInferred/",
                exceptions: []
            )
        ]

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: true
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        XCTAssertEqual(sideEffects.count, 0)

        let target = try XCTUnwrap(targets.first)

        XCTAssertEqual(target.sources, [])
        XCTAssertEqual(target.buildableFolders, expectedBuildableFolders)
    }

    func testBuildableFolderInference_notSuitedBecauseOfMultipleSources() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "NativeTarget",
            sourceFiles: [
                "Sources/ShouldNotBeInferred/**/*",
                "Sources/ShouldNotBeInferred2/**/*",
            ],
            moduleMap: CocoapodsSpec.ModuleMap.none
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()
        _ = try createFiles([
            "Sources/ShouldBeInferred/File1.swift",
            "Sources/ShouldBeInferred/File2.swift",
            "Sources/ShouldNotBeInferred/File3.swift",
            "Sources/ShouldNotBeInferred2/File3.swift",
        ])

        // act
        let (targets, sideEffects) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: true
        )

        // assert
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.product, .framework)
        XCTAssertEqual(sideEffects.count, 0)

        var target = try XCTUnwrap(targets.first)
        for i in 0 ..< target.sources.count {
            target.sources[i].paths.sort()
        }

        XCTAssertEqual(target.sources, [
            SourceFiles(paths: [
                "Sources/ShouldNotBeInferred/**/*",
                "Sources/ShouldNotBeInferred2/**/*",
            ])
        ])
        XCTAssertEqual(target.buildableFolders, [])
    }

    func testAppSpecsContainsDefaultCFBundleVersion() throws {
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
              "appspecs": [
                {
                  "name": "Example",
                  "source_files": "C/C.swift",
                }
              ],
            }
            """.data(using: .utf8)
        try createFiles(
            [
                "A/A.swift",
                "C/C.swift",
            ]
        )

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)

        // act
        let (targets, _) = try g.appTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: "/Unused",
            appHostDir: "/Unused",
            buildableFolderInference: false
        )
        let appTarget = try XCTUnwrap(targets.first)

        let infoPlistDict: [String: Plist.Value]
        if case let .extendingDefault(with: dict) = appTarget.infoPlist {
            infoPlistDict = dict
        } else {
            infoPlistDict = [:]
            XCTFail("infoPlistDict should be set")
        }

        // assert
        XCTAssertEqual(appTarget.settings?.base["CURRENT_PROJECT_VERSION"], "1")
        XCTAssertEqual(infoPlistDict["CFBundleVersion"], "$(CURRENT_PROJECT_VERSION)")
    }

    func testAppSpecsOverrideDefaultVersioning() throws {
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
              "appspecs": [
                {
                  "name": "Example",
                  "source_files": "C/C.swift",
                  "info_plist": {
                    "CFBundleVersion": "777"
                  },
                  "pod_target_xcconfig": {
                    "CURRENT_PROJECT_VERSION": "666",
                  }
                }
              ],
            }
            """.data(using: .utf8)
        try createFiles(
            [
                "A/A.swift",
                "C/C.swift",
            ]
        )

        let spec = try JSONDecoder().decode(CocoapodsSpec.self, from: XCTUnwrap(specSrc))
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let g = CocoapodsTargetGenerator(fileHandler: fileHandler)

        // act
        let (targets, _) = try g.appTargets(
            for: provider,
            path: temporaryPath(),
            moduleMapDir: "/Unused",
            appHostDir: "/Unused",
            buildableFolderInference: false
        )
        let appTarget = try XCTUnwrap(targets.first)

        let infoPlistDict: [String: Plist.Value]
        if case let .extendingDefault(with: dict) = appTarget.infoPlist {
            infoPlistDict = dict
        } else {
            infoPlistDict = [:]
            XCTFail("infoPlistDict should be set")
        }

        // assert
        XCTAssertEqual(appTarget.settings?.base["CURRENT_PROJECT_VERSION"], "666")
        XCTAssertEqual(infoPlistDict["CFBundleVersion"], "777")
    }

    func testBinaryTargetsGeneration() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "BinarySpec",
            dependencies: [
                "XCTest": [],
                "Dependency1": [],
            ],
            vendoredFrameworks: [
                "subpath/framework1.xcframework",
                "subpath/framework2.framework",
            ],
            frameworks: ["CoreData"],
            weakFrameworks: ["UIKit"],
            libraries: ["sqlite3"]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        let generator = CocoapodsTargetGenerator()
        let path = try AbsolutePath(validating: "/path")

        // act
        let (binaryTargets, dependencies) = try generator.binaryTargets(for: provider, path: path)

        // assert
        let expectedTargets: [CocoapodsPrecompiledTarget] = [
            .framework(path: path.appending(components: ["subpath", "framework2.framework"])),
            .xcframework(path: path.appending(components: ["subpath", "framework1.xcframework"])),
        ]
        let expectedDependencies: [ProjectDescription.TargetDependency] = [
            .xctest,
            .external(name: "Dependency1", condition: nil),
            .sdk(name: "CoreData", type: .framework, status: .required),
            .sdk(name: "UIKit", type: .framework, status: .optional),
            .sdk(name: "sqlite3", type: .library, status: .required),
        ]
        XCTAssertEqual(
            binaryTargets.sorted { $1.path > $0.path },
            expectedTargets.sorted { $1.path > $0.path }
        )
        XCTAssertEqual(
            dependencies.sorted { $1.name > $0.name },
            expectedDependencies.sorted { $1.name > $0.name }
        )
    }
    
    func testGetProductType_staticFramework_withoutForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: [],
            staticFramework: nil
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            forceLinking: [:]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .staticFramework)
    }
    
    func testGetProductType_withSources_withoutdefaultForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: ["a.swift"],
            staticFramework: nil
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            defaultForceLinking: nil,
            forceLinking: [:]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .framework)
    }
    
    func testGetProductType_withSources_withdefaultForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: ["a.swift"],
            staticFramework: nil
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            defaultForceLinking: .static,
            forceLinking: [:]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .staticFramework)
    }
    
    func testGetProductType_withSources_withdefaultForceLinking_withForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: ["a.swift"],
            staticFramework: nil
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)
        
        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            defaultForceLinking: .static,
            forceLinking: [
                "a": .dynamic
            ]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .framework)
    }
    
    func testGetProductType_staticFramework_withForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: []
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)

        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            forceLinking: [
                "a": .static
            ]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .staticFramework)
    }

    func testGetProductType_dynamicFramework_withForceLinking() throws {
        // arrange
        let spec = CocoapodsSpec.test(
            name: "a",
            sourceFiles: ["a"]
        )
        let provider = CocoapodsSpecInfoProvider(spec: spec)

        let generator = CocoapodsTargetGenerator()
        let path = try temporaryPath()

        // act
        let (targets, _) = try generator.nativeTargets(
            for: provider, path: path,
            moduleMapDir: path, appHostDir: path,
            buildableFolderInference: false,
            includeEmptyTargets: true,
            forceLinking: [
                "a": .dynamic
            ]
        )

        // assert
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(target.product, .framework)
    }
}

extension ProjectDescription.TargetDependency {
    fileprivate var name: String {
        switch self {
        case let .target(name, _, _):
            return name
        case let .local(name, _, _):
            return name
        case let .project(target, _, _, _):
            return target
        case let .framework(path, _, _):
            return path.pathString
        case let .library(path, _, _, _):
            return path.pathString
        case let .sdk(name, _, _, _):
            return name
        case let .xcframework(path, _, _):
            return path.pathString
        case let .bundle(path, _):
            return path.pathString
        case .xctest:
            return "XCTest"
        case let .external(name, _):
            return name
        }
    }
}

extension CocoapodsPrecompiledTarget {
    var path: AbsolutePath {
        switch self {
        case let .bundle(path, _):
            return path
        case let .framework(path, _):
            return path
        case let .xcframework(path, _):
            return path
        case let .library(path, _):
            return path
        }
    }
}
