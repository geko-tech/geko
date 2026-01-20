import Foundation
import GekoCacheTesting
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class DependenciesContentHasherTests: GekoUnitTestCase {
    private var subject: DependenciesContentHasher!
    private var mockContentHasher: MockContentHasher!
    private var filePath1: AbsolutePath! = try! AbsolutePath(validating: "/file1")
    private var filePath2: AbsolutePath! = try! AbsolutePath(validating: "/file2")
    private var filePath3: AbsolutePath! = try! AbsolutePath(validating: "/file3")
    private var filePath4: AbsolutePath! = try! AbsolutePath(validating: "/file4/TestFramework.xcframework")
    private var graphTarget: GraphTarget!
    private var hashedTargets: Atomic<[GraphHashedTarget: String]>!
    private var hashedPaths: Atomic<[AbsolutePath: String]>!

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        hashedTargets = Atomic(wrappedValue: [:])
        hashedPaths = Atomic(wrappedValue: [:])
        subject = DependenciesContentHasher(contentHasher: mockContentHasher)
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        hashedTargets = nil
        hashedPaths = nil
        graphTarget = nil
        filePath1 = nil
        filePath2 = nil
        filePath3 = nil
        super.tearDown()
    }

    func test_hash_whenDependencyIsTarget_returnsTheRightHash() throws {
        // Given
        let dependency = TargetDependency.target(name: "foo")

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        hashedTargets.modify { value in
            value[GraphHashedTarget(projectPath: graphTarget.path, targetName: "foo")] = "target-foo-hash"
        }
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "target-foo-hash")
    }

    func test_hash_whenDependencyIsTarget_throwsWhenTheDependencyHasntBeenHashed() throws {
        // Given
        let dependency = TargetDependency.target(name: "foo")

        // When/Then
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let expectedError = DependenciesContentHasherError.missingTargetHash(
            sourceTargetName: graphTarget.target.name,
            dependencyProjectPath: graphTarget.path,
            dependencyTargetName: "foo"
        )
        XCTAssertThrowsSpecific(
            try subject.hash(
                graphTarget: graphTarget,
                hashedTargets: hashedTargets,
                hashedPaths: hashedPaths,
                externalDepsTree: [:],
                swiftModuleCacheEnabled: false
            ),
            expectedError
        )
    }

    func test_hash_whenDependencyIsProject_returnsTheRightHash() throws {
        // Given
        let dependency = TargetDependency.project(target: "foo", path: filePath1)

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        hashedTargets.modify { value in
            value[GraphHashedTarget(projectPath: filePath1, targetName: "foo")] = "project-file-hashed-foo-hash"
        }
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "project-file-hashed-foo-hash")
    }

    func test_hash_whenDependencyIsProject_throwsAnErrorIfTheDependencyHashDoesntExist() throws {
        // Given
        let dependency = TargetDependency.project(target: "foo", path: filePath1)

        // When/Then
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let expectedError = DependenciesContentHasherError.missingProjectTargetHash(
            sourceProjectPath: graphTarget.path,
            sourceTargetName: graphTarget.target.name,
            dependencyProjectPath: filePath1,
            dependencyTargetName: "foo"
        )
        XCTAssertThrowsSpecific(
            try subject.hash(
                graphTarget: graphTarget,
                hashedTargets: hashedTargets,
                hashedPaths: hashedPaths,
                externalDepsTree: [:],
                swiftModuleCacheEnabled: false
            ),
            expectedError
        )
    }

    func test_hash_whenDependencyIsFramework_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.framework(path: filePath1, status: LinkingStatus.required)
        mockContentHasher.stubHashForPath[filePath1] = "file-hashed"

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "file-hashed")
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 1)
    }

    func test_hash_whenDependencyIsXCFramework_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.xcframework(path: filePath1, status: .required)
        mockContentHasher.stubHashForPath[filePath1] = "file-hashed"

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "file-hashed")
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 1)
    }
    
    func test_hash_whenDependencyIsXCFramework_withSwiftModuleCache_callsContentsHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.xcframework(path: filePath4, status: .required)
        var hashedStrings: [String] = []
        mockContentHasher.hashStub = {
            hashedStrings.append($0)
            return $0
        }
        let externalDepsTree = ["TestFramework": GekoGraph.DependenciesGraph.TreeDependency(version: "1.0.0", dependencies: [])]
        
        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        
        let _ = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: externalDepsTree,
            swiftModuleCacheEnabled: true
        )

        // Then
        XCTAssertEqual(hashedStrings, ["1.0.0"])
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }
    
    func test_hash_whenDependencyIsXCFramework_withSwiftModuleCache_callsContentsHasherWithoutVersion() throws {
        // Given
        let dependency = TargetDependency.xcframework(path: filePath4, status: .required)
        mockContentHasher.stubHashForPathWithExclude[filePath4] = "file-hashed"
        
        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: true
        )

        // Then
        XCTAssertEqual(hash.0, "file-hashed")
        XCTAssertEqual(mockContentHasher.hashPathWithExcludeCallCount, 1)
    }

    func test_hash_whenDependencyIsLibrary_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.library(
            path: filePath1,
            publicHeaders: filePath2,
            swiftModuleMap: filePath3
        )
        mockContentHasher.stubHashForPath[filePath1] = "file1-hashed"
        mockContentHasher.stubHashForPath[filePath2] = "file2-hashed"
        mockContentHasher.stubHashForPath[filePath3] = "file3-hashed"

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "library-file1-hashed-file2-hashed-file3-hashed-hash")
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 3)
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }

    func test_hash_whenDependencyIsLibrary_swiftModuleMapIsNil_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.library(
            path: filePath1,
            publicHeaders: filePath2,
            swiftModuleMap: nil
        )
        mockContentHasher.stubHashForPath[filePath1] = "file1-hashed"
        mockContentHasher.stubHashForPath[filePath2] = "file2-hashed"

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "library-file1-hashed-file2-hashed-hash")
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 2)
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }

    func test_hash_whenDependencyIsOptionalSDK_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.sdk(name: "foo", type: .framework, status: .optional)

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "sdk-foo-optional-hash")
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }

    func test_hash_whenDependencyIsRequiredSDK_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.sdk(name: "foo", type: .framework, status: .required)

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "sdk-foo-required-hash")
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }

    func test_hash_whenDependencyIsXCTest_callsContentHasherAsExpected() throws {
        // Given
        let dependency = TargetDependency.xctest

        // When
        let graphTarget = GraphTarget.test(target: Target.test(dependencies: [dependency]))
        let hash = try subject.hash(
            graphTarget: graphTarget,
            hashedTargets: hashedTargets,
            hashedPaths: hashedPaths,
            externalDepsTree: [:],
            swiftModuleCacheEnabled: false
        )

        // Then
        XCTAssertEqual(hash.0, "xctest-hash")
        XCTAssertEqual(mockContentHasher.hashStringCallCount, 1)
    }
}
