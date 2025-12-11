import Foundation
import XCTest

@testable import GekoCache
@testable import GekoSupportTesting

final class CacheLocalStorageErrorTests: GekoUnitTestCase {
    func test_type() {
        XCTAssertEqual(CacheLocalStorageError.compiledArtifactNotFound(hash: "hash").type, .abort)
    }

    func test_description() {
        XCTAssertEqual(
            CacheLocalStorageError.compiledArtifactNotFound(hash: "hash").description,
            "xcframework with hash 'hash' not found in the local cache"
        )
    }
}
