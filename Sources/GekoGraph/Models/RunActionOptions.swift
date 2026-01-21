import Foundation
import ProjectDescription

extension RunActionOptions.SimulatedLocation {
    /// A unique identifier string for the selected simulated location.
    ///
    /// In case of Xcode's simulated locations, this is a string representing the location.
    /// In case of a custom GPX file, this is a path to that file.
    public var identifier: String {
        switch self {
        case let .gpxFile(path):
            return path.pathString
        case let .reference(identifier):
            return identifier
        }
    }

    /// A reference type is 1 if using Xcode's built-in simulated locations.
    /// Otherwise, it is 0.
    public var referenceType: String {
        if case .gpxFile = self { return "0" }
        return "1"
    }
}
