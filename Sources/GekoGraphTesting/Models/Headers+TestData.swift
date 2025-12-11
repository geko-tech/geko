import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoGraph

extension Headers {
    public static func test(
        public: [AbsolutePath] = [],
        private: [AbsolutePath] = [],
        project: [AbsolutePath] = []
    ) -> Headers {
        return .headers(
            public: .list(`public`),
            private: .list(`private`),
            project: .list(project),
            mappingsDir: nil
        )
    }
}
