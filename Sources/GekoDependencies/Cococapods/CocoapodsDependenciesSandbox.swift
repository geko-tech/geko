import Foundation
import GekoGraph
import ProjectDescription

public struct CocoapodsDependenciesSandbox: Codable, Equatable {
    public let dependencies: CocoapodsDependencies
    public let lockfile: CocoapodsLockfile
}
