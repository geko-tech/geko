import Foundation
import GekoGraph

public struct CocoapodsDependenciesSandbox: Codable, Equatable {
    public let dependencies: GekoGraph.CocoapodsDependencies
    public let lockfile: CocoapodsLockfile
}
