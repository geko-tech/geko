import Foundation
import GekoSupportTesting
import ProjectDescription

@testable import GekoGraph

extension Cloud {
    public static func test(
        url: URL = URL.test(),
        bucket: String = "test_bucket"
    ) -> Cloud {
        .cloud(bucket: bucket, url: url.absoluteString)
    }
}
