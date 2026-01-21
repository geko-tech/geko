import Foundation
import ProjectDescription

// MARK: - Array + ProjectOption

extension Project.Options {
    public var targetSchemesGrouping: AutomaticSchemesOptions.TargetSchemesGrouping? {
        switch automaticSchemesOptions {
        case let .enabled(targetSchemesGrouping, _, _, _, _, _, _, _, _):
            return targetSchemesGrouping
        case .disabled:
            return nil
        }
    }

    public var codeCoverageEnabled: Bool {
        switch automaticSchemesOptions {
        case let .enabled(_, codeCoverageEnabled, _, _, _, _, _, _, _):
            return codeCoverageEnabled
        case .disabled:
            return false
        }
    }

    public var testingOptions: TestingOptions {
        switch automaticSchemesOptions {
        case let .enabled(_, _, testingOptions, _, _, _, _, _, _):
            return testingOptions
        case .disabled:
            return []
        }
    }

    public var testLanguage: String? {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, language, _, _, _, _, _):
            return language?.identifier
        case .disabled:
            return nil
        }
    }

    public var testRegion: String? {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, _, region, _, _, _, _):
            return region
        case .disabled:
            return nil
        }
    }

    public var testScreenCaptureFormat: ScreenCaptureFormat? {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, _, _, testScreenCaptureFormat, _, _, _):
            return testScreenCaptureFormat
        case .disabled:
            return nil
        }
    }

    public var runLanguage: String? {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, _, _, _, language, _, _):
            return language?.identifier
        case .disabled:
            return nil
        }
    }

    public var runRegion: String? {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, _, _, _, _, region, _):
            return region
        case .disabled:
            return nil
        }
    }

    public var testPlans: [String] {
        switch automaticSchemesOptions {
        case let .enabled(_, _, _, _, _, _, _, _, testPlans):
            return testPlans
        case .disabled:
            return []
        }
    }
}
