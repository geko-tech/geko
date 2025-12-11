import Foundation
import GekoGraph
import GekoSupport

extension BuildConfiguration: XcodeRepresentable {
    public var xcodeValue: String { name }
}
