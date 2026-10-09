import Crypto
import Foundation
import ProjectDescription
import XcodeProj

/// Describes a generated `.xctestplan` file.
public struct XCTestPlanDescriptor: Equatable {

    /// Absolute path where the generated `.xctestplan` will be written.
    public let path: AbsolutePath
    /// The test plan that will be written to the disk.
    public let plan: XCTestPlan?

    public init(
        path: AbsolutePath,
        plan: XCTestPlan?
    ) {
        self.path = path
        self.plan = plan
    }

    // MARK: - Public

    public func sideEffectDescriptors() throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = [
            .file(FileDescriptor(path: path, state: .absent))
        ]

        if let plan {
            sideEffects.append(
                .file(FileDescriptor(path: path, contents: try encode(plan: plan)))
            )
        }

        return sideEffects
    }

    // MARK: - Private

    private func encode(plan: XCTestPlan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(plan)
    }
}

public extension [XCTestPlanDescriptor] {

    func sideEffectDescriptors() throws -> [SideEffectDescriptor] {
        try flatMap {
            try $0.sideEffectDescriptors()
        }
    }
}
