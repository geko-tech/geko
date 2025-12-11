import Foundation

public protocol Package: Hashable {
    var name: String { get }
}
