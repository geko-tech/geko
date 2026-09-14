import GekoGraph
import GekoSupport
import ProjectDescription

public protocol InspectTargetsServicing {
    func run(
        path: AbsolutePath,
        files: [String],
        graph: Graph
    ) throws
}

public final class InspectTargetsService: InspectTargetsServicing {
    // MARK: - Attributes
    
    private let targetOwnershipResolver: TargetFileOwnershipResolving
    private let outputRenderer: TargetOwnershipOutputRendering
    
    // MARK: - Init
    
    public init(
        targetOwnershipResolver: TargetFileOwnershipResolving = TargetFileOwnershipResolver(),
        outputRenderer: TargetOwnershipOutputRendering = TargetOwnershipOutputRenderer()
    ) {
        self.targetOwnershipResolver = targetOwnershipResolver
        self.outputRenderer = outputRenderer
    }
    
    // MARK: - InspectTargetsServicing
    
    public func run(
        path: AbsolutePath,
        files: [String],
        graph: Graph
    ) throws {
        let inputFiles = try files.map {
            try AbsolutePath(validating: $0, relativeTo: path)
        }
        let ownerships = try targetOwnershipResolver.resolve(inputFiles, graph: graph)
        outputRenderer.render(
            ownerships,
            rootPath: path,
            infoMessage: "Targets containing the specified files:\n"
        )
    }
}
