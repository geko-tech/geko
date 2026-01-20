import Foundation
import GekoSupport
import ProjectDescription

@testable import GekoGraph

extension FrameworkMetadata {
    public static func test(
        path: AbsolutePath = "/Frameworks/TestFramework.xframework",
        binaryPath: AbsolutePath = "/Frameworks/TestFramework.xframework/TestFramework",
        dsymPath: AbsolutePath? = nil,
        bcsymbolmapPaths: [AbsolutePath] = [],
        linking: BinaryLinking = .dynamic,
        architectures: [BinaryArchitecture] = [.arm64],
        status: LinkingStatus = .required
    ) -> FrameworkMetadata {
        FrameworkMetadata(
            path: path,
            binaryPath: binaryPath,
            dsymPath: dsymPath,
            bcsymbolmapPaths: bcsymbolmapPaths,
            linking: linking,
            architectures: architectures,
            status: status
        )
    }
}
