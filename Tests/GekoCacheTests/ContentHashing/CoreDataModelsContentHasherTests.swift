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

final class CoreDataModelsContentHasherTests: GekoUnitTestCase {
    private var subject: CoreDataModelsContentHasher!
    private var coreDataModel: CoreDataModel!
    private var mockContentHasher: MockContentHasher!
    private let defaultValuesHash =
        "05c9d517e2cf12b45786787dae929a23" // Expected hash for the CoreDataModel created with the buildCoreDataModel function
    // using default values

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = CoreDataModelsContentHasher(contentHasher: mockContentHasher)
        do {
            _ = try TemporaryDirectory(removeTreeOnDeinit: true)
        } catch {
            XCTFail("Error while creating temporary directory")
        }
    }

    override func tearDown() {
        subject = nil
        coreDataModel = nil
        mockContentHasher = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hash_returnsSameValue() throws {
        // Given
        coreDataModel = try buildCoreDataModel(versions: ["v1", "v2"], currentVersion: "currentV1")

        // When
        let hash = try subject.hash(coreDataModels: [coreDataModel])
        
        // Then
        XCTAssertEqual(hash.0, "../../../../../../v1;../../../../../../v2;fixed-hash;currentV1")
    }

    func test_hash_fileContentChangesHash() throws {
        // Given
        let name = "CoreDataModel"
        coreDataModel = try buildCoreDataModel()
        let fakePath = buildFakePath(from: name)
        mockContentHasher.stubHashForPath[fakePath] = "different-hash"

        // When
        let hash = try subject.hash(coreDataModels: [coreDataModel])

        // Then
        XCTAssertNotEqual(hash.0, defaultValuesHash)
    }

    func test_hash_currentVersionChangesHash() throws {
        // Given
        coreDataModel = try buildCoreDataModel(currentVersion: "2")

        // When
        let hash = try subject.hash(coreDataModels: [coreDataModel])

        XCTAssertNotEqual(hash.0, defaultValuesHash)
    }

    func test_hash_versionsChangeHash() throws {
        // Given
        coreDataModel = try buildCoreDataModel(versions: ["1", "2", "3"])

        // When
        let hash = try subject.hash(coreDataModels: [coreDataModel])

        // Then
        XCTAssertNotEqual(hash.0, defaultValuesHash)
    }

    // MARK: - Private

    private func buildFakePath(from name: String) -> AbsolutePath {
        try! AbsolutePath(validating: "/\(name)+path")
    }

    private func buildCoreDataModel(
        name: String = "CoreDataModel",
        versions: [String] = ["1", "2"],
        currentVersion: String = "1"
    ) throws -> CoreDataModel {
        let fakePath = buildFakePath(from: name)
        mockContentHasher.stubHashForPath[fakePath] = "fixed-hash"
        let versionsAbsolutePaths = try versions.map { try AbsolutePath(validating: "/\($0)") }
        return CoreDataModel(
            fakePath,
            versions: versionsAbsolutePaths,
            currentVersion: currentVersion
        )
    }
}
