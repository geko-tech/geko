import Foundation

import typealias ProjectDescription.Destinations
import enum ProjectDescription.Destination

public typealias Destinations = ProjectDescription.Destinations
public typealias Destination = ProjectDescription.Destination

extension Destination {
    public var platformFilter: PlatformFilter {
        switch self {
        case .iPad, .iPhone, .macWithiPadDesign, .appleVisionWithiPadDesign:
            return .ios
        case .macCatalyst:
            return .catalyst
        case .mac:
            return .macos
        case .appleTv:
            return .tvos
        case .appleWatch:
            return .watchos
        case .appleVision:
            return .visionos
        }
    }
}

extension Collection<Destination> {
    public func supports(_ platform: Platform) -> Bool {
        contains(where: { $0.platform == platform })
    }
}
