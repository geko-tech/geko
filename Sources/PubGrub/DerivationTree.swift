import Collections
import Foundation

public protocol Reporter {
    associatedtype Output
    associatedtype P: Package
    associatedtype V: Version

    static func report(derivationTree: DerivationTree<P, V>) -> Output
}

public class Box<T> {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }

    func clone() -> Box<T> {
        .init(value)
    }
}

public enum External<P: Package, V: Version>: CustomStringConvertible {
    case notRoot(P, V)
    case noVersions(P, VersionRange<V>)
    case unavailableDependencies(P, VersionRange<V>)
    case fromDependencyOf(P, VersionRange<V>, P, VersionRange<V>)

    public var description: String {
        switch self {
        case let .notRoot(package, version):
            return "we are solving dependencies of \(package.name) \(version.value)"
        case let .noVersions(package, range):
            if range == VersionRange<V>.any() {
                return "there are no available version for \(package.name)"
            } else {
                return "there is no version of \(package.name) in \(range)"
            }
        case let .unavailableDependencies(package, range):
            if range == VersionRange<V>.any() {
                return "dependencies of \(package.name) are unavailable"
            } else {
                return "dependencies of \(package.name) at version \(range) are unavailable"
            }
        case let .fromDependencyOf(p, rangeP, dep, rangeDep):
            if rangeP == VersionRange<V>.any(), rangeDep == VersionRange<V>.any() {
                return "\(p.name) depends on \(dep.name)"
            } else if rangeP == VersionRange<V>.any() {
                return "\(p.name) depends on \(dep.name) \(rangeDep)"
            } else if rangeP == VersionRange<V>.any() {
                return "\(p.name) \(rangeP) depends on \(dep.name)"
            } else {
                return "\(p.name) \(rangeP) depends on \(dep.name) \(rangeDep)"
            }
        }
    }
}

public struct Derived<P: Package, V: Version> {
    public let terms: OrderedDictionary<P, Term<V>>

    public let sharedId: Int?
    public let cause1: Box<DerivationTree<P, V>>
    public let cause2: Box<DerivationTree<P, V>>
}

public enum DerivationTree<P: Package, V: Version> {
    case external(External<P, V>)
    case derived(Derived<P, V>)

    mutating func collapseNoVersions() {
        guard case let .derived(derived) = self else {
            return
        }

        switch (derived.cause1.value, derived.cause2.value) {
        case (let .external(External.noVersions(p, r)), var cause2):
            cause2.collapseNoVersions()
            self = cause2.mergeNoVersions(package: p, range: r)
        case (var cause1, let .external(External.noVersions(p, r))):
            cause1.collapseNoVersions()
            self = cause1.mergeNoVersions(package: p, range: r)
        default:
            derived.cause1.value.collapseNoVersions()
            derived.cause2.value.collapseNoVersions()
        }
    }

    func mergeNoVersions(package: P, range: VersionRange<V>) -> DerivationTree<P, V> {
        switch self {
        case .derived:
            return self
        case .external(External.notRoot):
            fatalError("How did we end up with a NoVersions merged with a NotRoot?")
        case let .external(External.noVersions(_, r)):
            return DerivationTree<P, V>.external(
                External<P, V>.noVersions(package, range.union(r))
            )
        case let .external(External.unavailableDependencies(_, r)):
            return DerivationTree<P, V>.external(
                External<P, V>
                    .unavailableDependencies(package, range.union(r))
            )
        case let .external(External.fromDependencyOf(p1, r1, p2, r2)):
            if p1 == package {
                return DerivationTree<P, V>.external(
                    External<P, V>.fromDependencyOf(p1, r1.union(range), p2, r2)
                )
            } else {
                return DerivationTree<P, V>.external(
                    External<P, V>.fromDependencyOf(p1, r1, p2, r2.union(range))
                )
            }
        }
    }
}

public struct DefaultStringReporter<P: Package, V: Version>: Reporter {
    var refCount: Int = 0
    var sharedWithRef: [Int: Int] = [:]
    var lines: [String] = []

    public init() {}

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
        "Because \(external1) and \(external2), \(stringTerms(currentTerms))"
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
        "Because \(stringTerms(derived.terms)) (\(refId)) and \(external), \(stringTerms(currentTerms))"
    }

    func andExplainExternal(
        _ external: External<P, V>,
        _ currentTerms: OrderedDictionary<P, Term<V>>
    ) -> String {
        "And because \(external), \(stringTerms(currentTerms))"
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
        "And because \(priorExternal) and \(external), \(stringTerms(currentTerms))"
    }

    func stringTerms(_ terms: OrderedDictionary<P, Term<V>>) -> String {
        let termsVec = terms.map { ($0, $1) }

        if termsVec.isEmpty {
            return "version solving failed"
        } else if termsVec.count == 1 {
            let (package, term) = termsVec[0]
            switch term {
            case let .positive(range):
                return "\(package.name) \(range) is forbidden"
            case let .negative(range):
                return "\(package.name) \(range) is mandatory"
            }
        } else if termsVec.count == 2 {
            let (p1, t1) = termsVec[0]
            let (p2, t2) = termsVec[1]
            switch (t1, t2) {
            case let (.positive(r1), .negative(r2)):
                return External<P, V>.fromDependencyOf(p1, r1, p2, r2).description
            case let (.negative(r1), .positive(r2)):
                return External<P, V>.fromDependencyOf(p1, r1, p2, r2).description
            default:
                break
            }
        }

        let strTerms = termsVec.map { p, t in
            "\(p.name) \(t)"
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

    public static func report(derivationTree: DerivationTree<P, V>) -> String {
        switch derivationTree {
        case let .external(external):
            return external.description
        case let .derived(derived):
            var reporter = DefaultStringReporter()
            reporter.buildRecursive(derived: derived)
            return reporter.lines.joined(separator: "\n")
        }
    }
}
