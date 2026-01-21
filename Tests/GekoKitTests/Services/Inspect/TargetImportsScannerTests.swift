import GekoSupport
import GekoSupportTesting
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoKit

final class TargetImportsScannerTests: GekoUnitTestCase {
    func test_scannerTargetWithImports() async throws {
        // Given
        let fileSystem = FileHandler.shared
        let path = try temporaryPath()
        let targetPath = path.appending(components: "FirstTarget", "Sources")

        let targetFirstFile = targetPath.appending(component: "FirstFile.swift")
        try fileSystem.touch(targetFirstFile)
        let targetSecondFile = targetPath.appending(component: "SecondFile.swift")
        try fileSystem.touch(targetSecondFile)
        
        try fileSystem.createFolder(path)
        try fileSystem.write(
            """
            import SecondTarget
            import A

            let a = 5
            """,
            path: targetFirstFile,
            atomically: true
        )
        
        try fileSystem.write(
            """
            import protocol FourthTarget.SomeProtocol
            import class FifthTarget.SomeClass
            @testable import ThirdTarget

            func main() { }
            """,
            path: targetSecondFile,
            atomically: true
        )

        let target = Target.test(
            name: "FirstTarget",
            sources: [
                SourceFiles(paths: [targetFirstFile]),
                SourceFiles(paths: [targetSecondFile]),
            ]
        )

        // When
        let result = try await TargetImportsScanner()
            .imports(for: target, sideEffects: [])

        // Then
        XCTAssertEqual(result.sorted(), ["SecondTarget", "ThirdTarget", "FourthTarget", "FifthTarget", "A"].sorted())
    }
    
    func test_scannerTargetWithImportsAndSideEffects() async throws {
        // Given
        let fileSystem = FileHandler.shared
        let path = try temporaryPath()
        let targetPath = path.appending(components: "FirstTarget", "Sources")

        let targetFirstFile = targetPath.appending(component: "FirstFile.swift")
        try fileSystem.touch(targetFirstFile)
        let targetSecondFile = targetPath.appending(component: "SecondFile.swift")
        try fileSystem.touch(targetSecondFile)
        
        try fileSystem.createFolder(path)
        try fileSystem.write(
            """
            import SecondTarget
            import A

            let a = 5
            """,
            path: targetFirstFile,
            atomically: true
        )
        
        try fileSystem.write(
            """
            import protocol FourthTarget.SomeProtocol
            import class FifthTarget.SomeClass
            @testable import ThirdTarget

            func main() { }
            """,
            path: targetSecondFile,
            atomically: true
        )
        let ignoreFilePath = targetPath.appending(component: "IgnoreFile.swift")
        let sideEffect = SideEffectDescriptor.file(FileDescriptor(path: ignoreFilePath))

        let target = Target.test(
            name: "FirstTarget",
            sources: [
                SourceFiles(paths: [targetFirstFile]),
                SourceFiles(paths: [targetSecondFile]),
                SourceFiles(paths: [ignoreFilePath])
            ]
        )

        // When
        let result = try await TargetImportsScanner()
            .imports(for: target, sideEffects: [sideEffect])

        // Then
        XCTAssertEqual(result.sorted(), ["SecondTarget", "ThirdTarget", "FourthTarget", "FifthTarget", "A"].sorted())
    }
}
