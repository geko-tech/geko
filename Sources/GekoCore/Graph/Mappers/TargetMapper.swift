import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol TargetMapping {
    func map(target: Target) throws -> (Target, [SideEffectDescriptor])
}
