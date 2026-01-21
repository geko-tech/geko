import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
import GekoCore

public enum CacheTaskError: FatalError {
    case cacheContextValueUninitialized
        
    public var description: String {
        switch self {
        case .cacheContextValueUninitialized:
            return "Some value from cacheContext used before it is initialized. This is probably an internal geko error."
        }
    }
    
    public var type: ErrorType {
        switch self {
        case .cacheContextValueUninitialized:
            return .abort
        }
    }
}

public struct CacheContext {
    // Immutable Values
    public let path: AbsolutePath
    public let config: Config
    public let cacheProfile: ProjectDescription.Cache.Profile
    public let outputType: CacheOutputType
    public let destination: CacheFrameworkDestination
    public let userFocusedTargets: Set<String>
    public let focusDirectDependencies: Bool
    public let focusTests: Bool
    public let unsafe: Bool
    public let dependenciesOnly: Bool
    public let scheme: String?
    
    // Mutable values
    public var graph: Graph?
    public var sideTable: GraphSideTable?
    public var hashesByCacheableTarget: [String: String]
    public var cacheableTargets: [(GraphTarget, String)]
    public var workspacePath: AbsolutePath?
    
    // Initialization
    
    public init(
        path: AbsolutePath,
        config: Config,
        cacheProfile: ProjectDescription.Cache.Profile,
        outputType: CacheOutputType,
        destination: CacheFrameworkDestination,
        userFocusedTargets: Set<String>,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?,
        graph: Graph? = nil,
        sideTable: GraphSideTable? = nil,
        hashesByCacheableTarget: [String : String] = [:],
        cacheableTargets: [(GraphTarget, String)] = [],
        workspacePath: AbsolutePath? = nil
    ) {
        self.path = path
        self.config = config
        self.cacheProfile = cacheProfile
        self.outputType = outputType
        self.destination = destination
        self.userFocusedTargets = userFocusedTargets
        self.focusDirectDependencies = focusDirectDependencies
        self.focusTests = focusTests
        self.unsafe = unsafe
        self.dependenciesOnly = dependenciesOnly
        self.scheme = scheme
        self.graph = graph
        self.sideTable = sideTable
        self.hashesByCacheableTarget = hashesByCacheableTarget
        self.cacheableTargets = cacheableTargets
        self.workspacePath = workspacePath
    }
}

public protocol CacheTask {
    func run(context: inout CacheContext) async throws
}
