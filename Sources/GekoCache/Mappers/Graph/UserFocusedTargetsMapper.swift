import ProjectDescription
import GekoCore
import GekoGraph

public final class UserFocusedTargetsMapper: GraphMapping {
    // MARK: - Attributes

    private let focusedTargets: Set<String>

    // MARK: - Initialization

    public init(
        focusedTargets: Set<String>
    ) {
        self.focusedTargets = focusedTargets
    }

    // MARK: - GraphMapping

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        let graphTraverser = GraphTraverser(graph: graph)
        let allTargets = graphTraverser.allTargets()

        let regexes = try focusedTargets.map { try Regex($0) }
        var filteredTargetsNames: Set<String> = []
        for target in allTargets {
            for regex in regexes {
                if try regex.wholeMatch(in: target.target.name) != nil {
                    filteredTargetsNames.insert(target.target.name)
                }
            }
        }

        sideTable.workspace.userFocusedTargets = filteredTargetsNames

        return []
    }
}
