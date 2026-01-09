import Collections
import Foundation

private let rootPackageName = "root"
private let rootPackageExplanation = "project"

public struct DefaultStringReporter<P: Package, V: Version> {
    var refCount: Int = 0
    var sharedWithRef: [Int: Int] = [:]
    var lines: [String] = []

    let dc: String // deafult color
    let hc: String // highlight color

    public init(colored: Bool = true) {
        if colored {
            dc = "\u{1B}[38;5;9m" // high intensity red foreground color
            hc = "\u{1B}[39m" // default foreground color
        } else {
            dc = ""
            hc = ""
        }
    }

    mutating func buildRecursive(derived: Derived<P, V>) {
        buildRecursiveHelper(current: derived)
        if let id = derived.sharedId {
            if sharedWithRef[id] == nil {
                addLineRef()
                sharedWithRef[id] = refCount
            }
        }
    }

    mutating func buildRecursiveHelper(current: Derived<P, V>) {
        switch (current.cause1.value, current.cause2.value) {
        case let (.external(external1), .external(external2)):
            lines.append(explainBothExternal(external1, external2, current.terms))
        case let (.derived(derived), .external(external)):
            reportOneEach(derived, external, current.terms)
        case let (.external(external), .derived(derived)):
            reportOneEach(derived, external, current.terms)
        case let (.derived(derived1), .derived(derived2)):
            switch (lineRefOf(derived1.sharedId), lineRefOf(derived2.sharedId)) {
            case let (.some(ref1), .some(ref2)):
                lines.append(explainBothRef(ref1, derived1, ref2, derived2, current.terms))
            case let (.some(ref1), .none):
                buildRecursive(derived: derived2)
                lines.append(andExplainRef(ref1, derived1, current.terms))
            case let (.none, .some(ref2)):
                buildRecursive(derived: derived1)
                lines.append(andExplainRef(ref2, derived2, current.terms))
            case (.none, .none):
                buildRecursive(derived: derived1)
                if derived1.sharedId == nil {
                    lines.append("")
                    buildRecursive(derived: current)
                } else {
                    addLineRef()
                    let ref1 = refCount
                    lines.append("")
                    buildRecursive(derived: derived2)
                    lines.append(andExplainRef(ref1, derived1, current.terms))
                }
            }
        }
    }

    mutating func reportOneEach(
        _ derived: Derived<P, V>,
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) {
        if let refId = lineRefOf(derived.sharedId) {
            lines.append(explainRefAndExternal(refId, derived, external, currentTerms))
        } else {
            reportRecursiveOneEach(derived, external, currentTerms)
        }
    }

    mutating func reportRecursiveOneEach(
        _ derived: Derived<P, V>,
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) {
        switch (derived.cause1.value, derived.cause2.value) {
        case let (.derived(priorDerived), .external(priorExternal)):
            buildRecursive(derived: priorDerived)
            lines.append(andExplainPriorAndExternal(priorExternal, external, currentTerms))
        case let (.external(priorExternal), .derived(priorDerived)):
            buildRecursive(derived: priorDerived)
            lines.append(andExplainPriorAndExternal(priorExternal, external, currentTerms))
        default:
            buildRecursive(derived: derived)
            lines.append(andExplainExternal(external, currentTerms))
        }
    }

    func explainBothExternal(
        _ external1: External<P, V>,
        _ external2: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "Because \(format(external: external1)) and \(format(external: external2)), \(stringTerms(currentTerms))"
    }

    func explainBothRef(
        _ refId1: Int,
        _ derived1: Derived<P, V>,
        _ refId2: Int,
        _ derived2: Derived<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "Because \(stringTerms(derived1.terms)) (\(refId1)) and \(stringTerms(derived2.terms)) (\(refId2)), \(stringTerms(currentTerms))."
    }

    func explainRefAndExternal(
        _ refId: Int,
        _ derived: Derived<P, V>,
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "Because \(stringTerms(derived.terms)) (\(refId)) and \(format(external: external)), \(stringTerms(currentTerms))"
    }

    func andExplainExternal(
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "And because \(format(external: external)), \(stringTerms(currentTerms))"
    }

    func andExplainRef(
        _ refId: Int,
        _ derived: Derived<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "And because \(stringTerms(derived.terms)) (\(refId)), \(stringTerms(currentTerms))"
    }

    func andExplainPriorAndExternal(
        _ priorExternal: External<P, V>,
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "And because \(format(external: priorExternal)) and \(format(external: external)), \(stringTerms(currentTerms))"
    }

    func stringTerms(_ terms: OrderedDictionary<P, Term<V>>) -> String {
        let termsVec = terms.map { ($0, $1) }

        if termsVec.isEmpty {
            return "package resolution failed"
        } else if termsVec.count == 1 {
            let (package, term) = termsVec[0]
            switch term {
            case let .positive(set):
                if package.name == rootPackageName {
                    return "package resolution failed"
                }
                return "\(format(package: package, set: set)) is forbidden"
            case let .negative(set):
                return "\(format(package: package, set: set)) is mandatory"
            }
        } else if termsVec.count == 2 {
            let (p1, t1) = termsVec[0]
            let (p2, t2) = termsVec[1]
            switch (t1, t2) {
            case let (.positive(r1), .negative(r2)):
                return format(external: .fromDependencyOf(p1, r1, p2, r2))
            case let (.negative(r1), .positive(r2)):
                return format(external: .fromDependencyOf(p2, r2, p1, r1))
            default:
                break
            }
        }

        let strTerms = termsVec.map { p, t in
            format(package: p, term: t)
        }
        if strTerms.count == 2 {
            return "\(strTerms[0]) is incompatible with \(strTerms[1])"
        } else {
            return strTerms.joined(separator: ", ") + " are incompatible"
        }
    }

    mutating func addLineRef() {
        let newCount = refCount + 1
        refCount = newCount
        if lines.count > 0 {
            lines[lines.count - 1] += " (\(newCount))"
        }
    }

    func lineRefOf(_ sharedId: Int?) -> Int? {
        sharedId.flatMap { sharedWithRef[$0] }
    }

    public static func report(derivationTree: DerivationTree<P, V>, colored: Bool = false) -> String {
        var reporter = DefaultStringReporter(colored: colored)

        switch derivationTree {
        case let .external(external):
            return "\(reporter.format(external: external))\(reporter.dc)"
        case let .derived(derived):
            reporter.buildRecursive(derived: derived)
            return "\(reporter.lines.joined(separator: "\n"))\(reporter.dc)"
        }
    }

    // MARK: - format functions

    func format(term: Term<V>) -> String {
        switch term {
        case let .positive(set):
            return format(set: set)
        case let .negative(set):
            return "Not ( \(format(set: set)) )"
        }
    }

    func format(package: P) -> String {
        if package.name == rootPackageName {
            return "\(hc)\(rootPackageExplanation)\(dc)"
        }
        return "\(hc)\(package.name)\(dc)"
    }

    func format(version: V) -> String {
        return "\(hc)\(version)\(dc)"
    }

    func format(set: VersionSet<V>) -> String {
        switch (set.release.isEmpty, set.preRelease.isEmpty) {
        case (true, true):
            return "\(hc)none\(dc)"
        case (false, true):
            return "\(hc)\(format(range: set.release))\(dc)"
        case (true, false):
            return "\(hc)\(format(range: set.preRelease))\(dc)"
        case (false, false):
            if set.isMonomorphic() {
                // if both release and pre-release ranges point to the same range (except pre-release components)
                // then collapse output to just pre-release range
                return "\(hc)\(format(range: set.preRelease))\(dc)"
            }
            return "\(hc){ release: \(format(range: set.release)), pre-release: \(format(range: set.preRelease)) }\(dc)"
        }
    }

    func format(range: VersionRange<V>) -> String {
        if range.segments.count == 1 {
            return format(interval: range.segments[0])
        }

        return range.segments.map { format(interval: $0) }.joined(separator: ", ")
    }

    func format(interval: VersionInterval<V>) -> String {
        if interval.upper == interval.lower {
            switch interval.lower {
            case let .included(version), let .excluded(version):
                return version.description
            case .unbounded:
                return "any"
            }
        }

        var components: [String] = []

        switch interval.lower {
        case let .included(v):
            components.append(">=\(v)")
        case let .excluded(v):
            components.append(">\(v)")
        case .unbounded:
            break
        }

        switch interval.upper {
        case let .included(v):
            components.append("<=\(v)")
        case let .excluded(v):
            components.append("<\(v)")
        case .unbounded:
            break
        }

        return components.joined(separator: " ")
    }

    func format(package: P, version: V) -> String {
        if package.name == rootPackageName {
            return "\(hc)\(rootPackageExplanation)\(dc)"
        }

        return "\(format(package: package)) \(format(version: version))"
    }

    func format(package: P, term: Term<V>) -> String {
        if package.name == rootPackageName {
            return "\(hc)\(rootPackageExplanation)\(dc)"
        }

        return "\(format(package: package)) \(format(term: term))"
    }

    func format(package: P, set: VersionSet<V>) -> String {
        if package.name == rootPackageName {
            return "\(hc)\(rootPackageExplanation)\(dc)"
        }

        if set == .any() {
            return "\(format(package: package))"
        }

        return "\(format(package: package)) \(format(set: set))"
    }

    func format(external: External<P, V>) -> String {
        switch external {
        case let .notRoot(package, version):
            return "we are solving dependencies of \(format(package: package, version: version))"
        case let .noVersions(package, set):
            if set == VersionSet<V>.any() {
                return "there are no available versions for \(format(package: package))"
            } else {
                return "there is no version of \(format(package: package)) in \(format(set: set))"
            }
        case let .unavailableDependencies(package, set):
            if set == VersionSet<V>.any() {
                return "dependencies of \(format(package: package)) are unavailable"
            } else {
                return "dependencies of \(format(package: package)) at version \(format(set: set)) are unavailable"
            }
        case let .fromDependencyOf(p, setP, dep, setDep):
            return "\(format(package: p, set: setP)) depends on \(format(package: dep, set: setDep))"
        }
    }
}

// MARK: - Helpers

private extension VersionSet {
    // returns true if both release and pre-release sets point to the same range (excluding pre-release components)
    func isMonomorphic() -> Bool {
        return release == preRelease.toReleaseRange()
    }
}

private extension VersionRange {
    func toReleaseRange() -> Self {
        var resultSegments: [VersionInterval<V>] = []

        for segment in segments {
            resultSegments.append(segment.toReleaseInterval())
        }

        return .init(segments: resultSegments)
    }
}

private extension VersionInterval {
    func toReleaseInterval() -> Self {
        return .init(self.lower.toReleaseLimit(), self.upper.toReleaseLimit())
    }
}

private extension VersionIntervalLimit {
    func toReleaseLimit() -> Self {
        switch self {
        case let .included(v):
            return .included(v.asReleaseVersion())
        case let .excluded(v):
            return .excluded(v.asReleaseVersion())
        case .unbounded:
            return .unbounded
        }
    }
}
