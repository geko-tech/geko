import Foundation
import ProjectDescription
import GekoCore
import GekoCoreTesting
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class TargetManifestMapperErrorTests: GekoUnitTestCase {
    func test_description_when_invalidResourcesGlob() {
        // Given
        let invalidGlobs: [InvalidGlob] = [.init(pattern: "/path/**/*", nonExistentPath: "/path/")]
        let subject = TargetManifestMapperError.invalidResourcesGlob(targetName: "Target", invalidGlobs: invalidGlobs)

        // When
        let got = subject.description

        // Then
        XCTAssertEqual(
            got,
            "The target Target has the following invalid resource globs:\n" + invalidGlobs.invalidGlobsDescription
        )
    }

    func test_sources() throws {
        // Given
        let temporaryPath = try temporaryPath()
        try createFiles([
            "sources/a.swift",
            "sources/b.h",
            "sources/b.m",
            "sources/c.mm",
            "sources/d.c",
            "sources/e.cpp",
            "sources/f.s",
            "sources/g.S",
            "sources/k.kt",
            "sources/n.metal",
        ])

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath, rootDirectoryLocator: MockRootDirectoryLocator())

        // When
        var target = Target.init(name: "target", destinations: .iOS, product: .app, sources: [
            SourceFiles(
                paths: [temporaryPath.appending(try RelativePath(validating: "sources/**"))],
                excluding: [],
                compilerFlags: nil
            ),
            SourceFiles(
                paths: [temporaryPath.appending(try RelativePath(validating: "sources/**"))],
                excluding: [],
                compilerFlags: nil
            ),
        ])

        try target.resolvePaths(generatorPaths: generatorPaths)
        try target.resolveGlobs(isExternal: false, projectType: .geko, checkFilesExist: true)
        try target.applyFixits()

        // Then
        let relativeSources = target.sources.flatMap { sourceFiles in
            sourceFiles.paths.map { $0.relative(to: temporaryPath).pathString }
        }

        XCTAssertEqual(Set(relativeSources), Set([
            "sources/a.swift",
            "sources/b.m",
            "sources/c.mm",
            "sources/d.c",
            "sources/f.s",
            "sources/g.S",
            "sources/e.cpp",
            "sources/n.metal",
        ]))
    }

    func test_sources_excluding_multiple_paths() throws {
        // Given
        let temporaryPath = try temporaryPath()
        try createFiles([
            "sources/a.swift",
            "sources/b.swift",
            "sources/aTests.swift",
            "sources/c/cType+Fake.swift",
            "sources/aType+Fake.swift",
            "sources/bTests.swift",
            "sources/kTests.kt",
            "sources/c/c.swift",
            "sources/c/cTests.swift",
            "sources/d.h",
            "sources/d.m",
            "sources/d/d.m",
        ])
        let excluding: [AbsolutePath] = [
            temporaryPath.appending(try RelativePath(validating: "sources/**/*Tests.swift")),
            temporaryPath.appending(try RelativePath(validating: "sources/**/*Fake.swift")),
            temporaryPath.appending(try RelativePath(validating: "sources/**/*.m")),
        ]
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath, rootDirectoryLocator: MockRootDirectoryLocator())

        // When
        var target = Target(
            name: "Target",
            destinations: .iOS,
            product: .app,
            sources: [
                SourceFiles(
                    glob: temporaryPath.appending(
                        try RelativePath(validating: "sources/**")
                    ),
                    excluding: excluding,
                    compilerFlags: nil
                ),
            ]
        )
        try target.resolvePaths(generatorPaths: generatorPaths)
        try target.resolveGlobs(isExternal: false, projectType: .geko, checkFilesExist: true)
        try target.applyFixits()

        // Then
        let relativeSources = target.sources.flatMap { sourceFiles in
            sourceFiles.paths.map {
                $0.relative(to: temporaryPath).pathString
            }
        }

        XCTAssertEqual(Set(relativeSources), Set([
            "sources/a.swift",
            "sources/b.swift",
            "sources/c/c.swift",
        ]))
    }

    func test_sources_excluding() throws {
        // Given
        let temporaryPath = try temporaryPath()
        try createFiles([
            "sources/a.swift",
            "sources/b.swift",
            "sources/aTests.swift",
            "sources/bTests.swift",
            "sources/kTests.kt",
            "sources/c/c.swift",
            "sources/c/cTests.swift",
        ])

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath, rootDirectoryLocator: MockRootDirectoryLocator())

        // When
        var target = Target(
            name: "Target",
            destinations: .iOS,
            product: .app,
            sources: [
                SourceFiles(
                    paths: [
                        temporaryPath.appending(try RelativePath(
                            validatingRelativePath: "sources/**"
                        ))
                    ],
                    excluding: [
                        temporaryPath.appending(try RelativePath(
                            validatingRelativePath: "sources/**/*Tests.swift"
                        ))
                    ],
                    compilerFlags: nil
                ),
            ]
        )
        try target.resolvePaths(generatorPaths: generatorPaths)
        try target.resolveGlobs(isExternal: false, projectType: .geko, checkFilesExist: true)
        try target.applyFixits()

        // Then
        let relativeSources = target.sources.flatMap { sourceFiles in
            sourceFiles.paths.map { $0.relative(to: temporaryPath).pathString }
        }

        XCTAssertEqual(Set(relativeSources), Set([
            "sources/a.swift",
            "sources/b.swift",
            "sources/c/c.swift",
        ]))
    }

    func test_sources_when_globs_are_invalid() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let error = FileHandlerError.nonExistentGlobDirectory(
            temporaryPath.appending(try RelativePath(validating: "invalid/path/**")).pathString,
            temporaryPath.appending(try RelativePath(validating: "invalid/path"))
        )
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath, rootDirectoryLocator: MockRootDirectoryLocator())

        // When
        XCTAssertThrowsSpecific(
            try {
                var target = Target(
                    name: "Target",
                    destinations: .iOS,
                    product: .app,
                    sources: [
                        SourceFiles(paths: [
                            temporaryPath
                                .appending(try RelativePath(
                                    validatingRelativePath: "invalid/path/**")
                                )
                        ]),
                    ]
                )
                try target.resolvePaths(generatorPaths: generatorPaths)
                try target.resolveGlobs(isExternal: false, projectType: .geko, checkFilesExist: true)
            }(),
            error
        )
    }

    func test_sources_include_header_files() throws {
        // Given
        let temporaryPath = try temporaryPath()
        try createFiles([
            "Sources/File1.swift",
            "Sources/File2.swift",
            "Sources/A/File3.swift",
            "Sources/A/File4.swift",
            "Sources/B/File5.h",
            "Sources/B/File6.c",
            "Sources/C/File7.h",
        ])
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath, rootDirectoryLocator: MockRootDirectoryLocator())

        // When
        var target = Target(
            name: "Target",
            destinations: .iOS,
            product: .app,
            sources: [
                SourceFiles(glob: temporaryPath.appending(
                    try RelativePath(validating: "Sources/**/*.{swift,c,h}")
                )),
            ]
        )
        try target.resolvePaths(generatorPaths: generatorPaths)
        try target.resolveGlobs(isExternal: false, projectType: .geko, checkFilesExist: true)
        try target.applyFixits()

        // Then
        let relativeSources = target.sources.flatMap { sourceFiles in
            sourceFiles.paths.map {
                $0.relative(to: temporaryPath).pathString
            }
        }

        XCTAssertEqual(Set(relativeSources), Set([
            "Sources/File1.swift",
            "Sources/File2.swift",
            "Sources/A/File3.swift",
            "Sources/A/File4.swift",
            "Sources/B/File6.c",
        ]))

        let relativeProjectHeaders = target.headers.flatMap { headers in
            headers.list.flatMap {
                $0.project?.files.map { $0.relative(to: temporaryPath) } ?? []
            }
        } ?? []

        XCTAssertEqual(Set(relativeProjectHeaders), Set([
            "Sources/B/File5.h",
            "Sources/C/File7.h",
        ]))
    }
}
