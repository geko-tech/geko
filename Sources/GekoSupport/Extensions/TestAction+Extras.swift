import ProjectDescription

public extension TestAction {

    var codeCoverableTargets: [TargetReference] {
        targets
            .filter { $0.isCoverable }
            .map { $0.target }
    }
}
