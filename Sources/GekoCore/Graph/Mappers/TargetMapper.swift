import Foundation
import GekoGraph
import GekoSupport

public protocol TargetMapping {
    func map(target: Target) throws -> (Target, [SideEffectDescriptor])
}
