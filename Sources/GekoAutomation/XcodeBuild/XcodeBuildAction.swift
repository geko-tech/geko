import GekoCore

/// An xcodebuild operation executed by Geko.
enum XcodeBuildAction: String, Encodable {
    case build
    case test
    case buildForTesting = "build-for-testing"
    case testWithoutBuilding = "test-without-building"
    case archive

    init(testAction: XcodeBuildTestAction) {
        switch testAction {
        case .test:
            self = .test
        case .build:
            self = .buildForTesting
        case .testWithoutBuilding:
            self = .testWithoutBuilding
        }
    }
}
