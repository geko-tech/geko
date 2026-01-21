import Foundation
import ProjectDescription

public enum AutogenerationOptions: Hashable {
    case disabled
    case enabled(TestingOptions)
}
