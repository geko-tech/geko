import ProjectDescription

public extension TestAction {

    var codeCoverableTargets: [TargetReference] {
        targets
            .filter { $0.isCoverageEnabled }
            .map { $0.target }
    }
}
