import Foundation
import ProjectDescription

public enum BinaryLinking: String, Hashable, Codable {
    case `static`, dynamic
}

extension Sequence<BinaryArchitecture> {
    /// Returns true if all the architectures are only for simulator.
    public var onlySimulator: Bool {
        let simulatorArchitectures: [BinaryArchitecture] = [.x8664, .i386, .arm64]
        return allSatisfy { simulatorArchitectures.contains($0) }
    }
}
