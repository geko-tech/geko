import Foundation

enum DeploymentTarget: String, CaseIterable {
    case simulator
    case device

    var title: String {
        switch self {
        case .simulator:
            "Simulator"
        case .device:
            "Device"
        }
    }
    
    static func fromTitle(_ string: String) -> DeploymentTarget? {
        if string == "Simulator" {
            return .simulator
        } else if string == "Device" {
            return .device
        } else {
            return nil
        }
    }
}
