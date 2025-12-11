import Foundation

public enum SpinnerAnimation {
    case geko

    public var frames: [String] {
        switch self {
        case .geko: return ["𓆊 ", "𓆌 "]
        }
    }

    public var defaultSpeed: Double {
        0.15
    }
}
