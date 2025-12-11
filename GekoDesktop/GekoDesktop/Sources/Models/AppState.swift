import Foundation

enum AppState: Equatable {
    case empty
    case prepare(String)
    case wrongEnvironment
    case idle
    case executing
    case appOutdated(Version)
}
