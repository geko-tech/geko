import Foundation

public protocol Version: Equatable, Hashable, Comparable {
    var value: String { get }

    static var lowest: Self { get }

    func bump() -> Self
}
