import ProjectDescription

public enum CocoapodsPlatform: String, CaseIterable, Codable {
    case `default`
    case iOS = "ios"
    case macOS = "osx"
    case watchOS = "watchos"
    case tvOS = "tvos"
    case visionOS = "visionos"
}

extension CocoapodsPlatform {
    public var caseValue: String? {
        switch self {
        case .default: return nil
        case .iOS: return "iOS"
        case .macOS: return "macOS"
        case .tvOS: return "tvOS"
        case .watchOS: return "watchOS"
        case .visionOS: return "visionOS"
        }
    }

    var condition: PlatformCondition? {
        switch self {
        case .default:
            return nil
        case .iOS:
            return .when([.ios])
        case .macOS:
            return .when([.macos])
        case .watchOS:
            return .when([.watchos])
        case .tvOS:
            return .when([.tvos])
        case .visionOS:
            return .when([.visionos])
        }
    }

    var destinations: Destinations {
        switch self {
        case .default:
            return [.iPhone, .iPad, .mac, .macWithiPadDesign, .macCatalyst, .appleWatch, .appleTv, .appleVision, .appleVisionWithiPadDesign]
        case .iOS:
            return .iOS
        case .macOS:
            return .macOS
        case .watchOS:
            return .watchOS
        case .tvOS:
            return .tvOS
        case .visionOS:
            return .visionOS
        }
    }

    func buildSettingKey(key: String) -> String {
        switch self {
        case .default:
            return key
        case .iOS:
            return "\(key)[sdk=\(Platform.iOS.xcodeDeviceOrSimulatorSDK)*]"
        case .macOS:
            return "\(key)[sdk=\(Platform.macOS.xcodeDeviceOrSimulatorSDK)*]"
        case .watchOS:
            return "\(key)[sdk=\(Platform.watchOS.xcodeDeviceOrSimulatorSDK)*]"
        case .tvOS:
            return "\(key)[sdk=\(Platform.tvOS.xcodeDeviceOrSimulatorSDK)*]"
        case .visionOS:
            return "\(key)[sdk=\(Platform.visionOS.xcodeDeviceOrSimulatorSDK)*]"
        }
    }

    var platformHeader: String {
        switch self {
        case .iOS, .tvOS, .default: return "#import <UIKit/UIKit.h>"
        case .macOS: return "#import <Cocoa/Cocoa.h>"
        case .visionOS, .watchOS: return "#import <Foundation/Foundation.h>"
        }
    }
}

extension Platform {
    var toCocoapodsPlatform: CocoapodsPlatform {
        switch self {
        case .iOS:
            return .iOS
        case .macOS:
            return .macOS
        case .tvOS:
            return .tvOS
        case .visionOS:
            return .visionOS
        case .watchOS:
            return .watchOS
        }
    }
    
    var cocoapodsPlatformHeader: String {
        switch self {
        case .iOS, .tvOS: return "#import <UIKit/UIKit.h>"
        case .macOS: return "#import <Cocoa/Cocoa.h>"
        case .visionOS, .watchOS: return "#import <Foundation/Foundation.h>"
        }
    }
}
