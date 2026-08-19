import Foundation

public enum SpinnerAnimation {
    case geko
    case classic

    public var frames: [String] {
        switch self {
        case .geko: return ["𓆊 ", "𓆌 "]
        case .classic: return [
            "⠋", "⠙", "⠹", "⠸",
            "⠼", "⠴", "⠦", "⠧",
            "⠇", "⠏",
        ]
        }
    }
    
    public var speed: Double {
        switch self {
        case .geko:
            return defaultSpeed
        case .classic:
            return 0.1
        }
    }

    public var defaultSpeed: Double {
        0.15
    }
}
