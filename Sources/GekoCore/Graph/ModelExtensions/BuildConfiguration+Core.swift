import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

extension BuildConfiguration: XcodeRepresentable {
    public var xcodeValue: String { name }
}
