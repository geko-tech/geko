import Foundation

public enum Term<V: Version>: Equatable {
    case positive(VersionSet<V>)
    case negative(VersionSet<V>)

    var isPositive: Bool {
        if case .positive = self {
            return true
        }
        return false
    }

    // MARK: - Initialization methods

    static func any() -> Term<V> {
        .negative(VersionSet<V>.none())
    }

    static func empty() -> Term<V> {
        .positive(VersionSet<V>.none())
    }

    static func exact(version: V) -> Term<V> {
        .positive(VersionSet<V>.exact(version: version))
    }

    // MARK: - Manipulation methods

    func negate() -> Self {
        switch self {
        case let .positive(versions):
            return .negative(versions)
        case let .negative(versions):
            return .positive(versions)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.positive(r1), .positive(r2)):
            return r1 == r2
        case let (.negative(r1), .negative(r2)):
            return r1 == r2
        default:
            return false
        }
    }

    public func contains(version: V) -> Bool {
        switch self {
        case let .positive(versions):
            return versions.contains(version)
        case let .negative(versions):
            return !versions.contains(version)
        }
    }

    public func unwrapPositive() -> VersionSet<V> {
        if case let .positive(versions) = self {
            return versions
        }
        fatalError("Negative term cannot unwrap positive range")
    }

    public func intersection(_ other: Term<V>) -> Term<V> {
        switch (self, other) {
        case let (.positive(r1), .positive(r2)):
            return .positive(r1.intersection(r2))
        case let (.positive(r1), .negative(r2)):
            return .positive(r1.intersection(r2.negate()))
        case let (.negative(r1), .positive(r2)):
            return .positive(r1.negate().intersection(r2))
        case let (.negative(r1), .negative(r2)):
            return .negative(r1.union(r2))
        }
    }

    public func union(_ other: Term<V>) -> Term<V> {
        (negate().intersection(other.negate())).negate()
    }

    public func subsetOf(_ other: Term<V>) -> Bool {
        self == intersection(other)
    }

    // MARK: - Relation between terms

    public func satisfiedBy(termsIntersection: Term<V>) -> Bool {
        termsIntersection.subsetOf(self)
    }

    public func contradictedBy(termsIntersection: Term<V>) -> Bool {
        termsIntersection.intersection(self) == .empty()
    }

    func relationWith(_ otherTermsIntersection: Term<V>) -> TermRelation {
        let fullIntersection = intersection(otherTermsIntersection)
        if fullIntersection == otherTermsIntersection {
            return .satisfied
        } else if fullIntersection == .empty() {
            return .contradicted
        } else {
            return .inconclusive
        }
    }
}

enum TermRelation {
    case satisfied
    case contradicted
    case inconclusive
}
