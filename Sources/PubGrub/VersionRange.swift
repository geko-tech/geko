import Foundation

public enum VersionIntervalLimit<V: Version>: Equatable {
    case included(V)
    case excluded(V)
    case unbounded
}

func endBeforeStartWithGap<V: Version>(end: VersionIntervalLimit<V>, start: VersionIntervalLimit<V>) -> Bool {
    switch (end, start) {
    case (_, .unbounded): return false
    case (.unbounded, _): return false
    case let (.included(left), .included(right)): return left < right
    case let (.included(left), .excluded(right)): return left < right
    case let (.excluded(left), .included(right)): return left < right
    case let (.excluded(left), .excluded(right)): return left <= right
    }
}

private func leftEndIsSmaller<V: Version>(left: VersionIntervalLimit<V>, right: VersionIntervalLimit<V>) -> Bool {
    switch (left, right) {
    case (_, .unbounded): return true
    case (.unbounded, _): return false
    case let (.included(l), .included(r)): return l <= r
    case let (.excluded(l), .excluded(r)): return l <= r
    case let (.excluded(l), .included(r)): return l <= r
    case let (.included(l), .excluded(r)): return l < r
    }
}

private func validSegment<V: Version>(start: VersionIntervalLimit<V>, end: VersionIntervalLimit<V>) -> Bool {
    switch (start, end) {
    // Singleton interval is allowed
    case let (.included(s), .included(e)): return s <= e
    case let (.included(s), .excluded(e)): return s < e
    case let (.excluded(s), .included(e)): return s < e
    case let (.excluded(s), .excluded(e)): return s < e
    case (.unbounded, _), (_, .unbounded): return true
    }
}

public struct VersionInterval<V: Version>: Equatable {
    public typealias Limit = VersionIntervalLimit<V>

    public var lower: Limit
    public var upper: Limit

    public init(_ lower: Limit, _ upper: Limit) {
        self.lower = lower
        self.upper = upper
    }
}

public struct VersionRange<V: Version>: Equatable {
    public typealias Limit = VersionIntervalLimit<V>

    public let segments: [VersionInterval<V>]

    public var isEmpty: Bool { return segments.isEmpty }

    // MARK: - Initialization methods

    /// Empty set of versions
    public static func none() -> VersionRange<V> {
        .init(segments: [])
    }

    /// Set of all possible versions
    public static func any() -> VersionRange<V> {
        // .higherThan(version: V.lowest)
        .init(segments: [VersionInterval(.unbounded, .unbounded)])
    }

    /// Set of all versions higher or equal to some version
    public static func higherThan(version: V) -> VersionRange<V> {
        .init(segments: [VersionInterval(.included(version), .unbounded)])
    }

    public static func exact(version: V) -> VersionRange<V> {
        .init(segments: [VersionInterval(.included(version), .included(version))])
    }

    public static func strictlyLowerThan(version: V) -> VersionRange<V> {
        return .init(segments: [VersionInterval(.unbounded, .excluded(version))])
    }

    public static func lowerThan(version: V) -> VersionRange<V> {
        return .init(segments: [VersionInterval(.unbounded, .included(version))])
    }

    public static func between(_ version1: V, _ version2: V) -> VersionRange<V> {
        precondition(version1 <= version2)
        return .init(segments: [VersionInterval(.included(version1), .excluded(version2))])
    }

    // MARK: - Utility functions

    #if DEBUG
    private func checkInvariants() {
        if self.segments.count > 1 {
            for i in 0 ..< (self.segments.count - 1) {
                assert(endBeforeStartWithGap(end: self.segments[i].upper, start: self.segments[i + 1].lower));
            }
        }
        for s in self.segments {
            assert(validSegment(start: s.lower, end: s.upper));
        }
    }
    #endif

    public func contains(_ version: V) -> Bool {
        for interval in segments {
            switch interval.lower {
            case .unbounded:
                break
            case let .included(lower):
                if version < lower { return false }
            case let .excluded(lower):
                if version <= lower { return false }
            }

            switch interval.upper {
            case .unbounded:
                return true
            case let .included(upper):
                if version <= upper { return true }
            case let .excluded(upper):
                if version < upper { return true }
            }
        }

        return false
    }

    // MARK: - Set operations

    // MARK: Negate

    public func negate() -> VersionRange<V> {
        guard let first = segments.first else {
            return .any()
        }

        switch (first.lower, first.upper) {
        case (.unbounded, .unbounded):
            return .none()
        case let (.included(lower), .unbounded):
            return .strictlyLowerThan(version: lower)
        case let (.excluded(lower), .unbounded):
            return .lowerThan(version: lower)
        case let (.unbounded, .included(upper)):
            return VersionRange.negateSegments(start: .excluded(upper), segments: Array(segments[1...]))
        case let (.unbounded, .excluded(upper)):
            return VersionRange.negateSegments(start: .included(upper), segments: Array(segments[1...]))
        default:
            return VersionRange.negateSegments(start: .unbounded, segments: segments)
        }
    }

    static func negateSegments(start: Limit, segments: [VersionInterval<V>]) -> VersionRange<V> {
        var result: [VersionInterval<V>] = []
        var start: Limit = start

        for interval in segments {
            let (v1, v2) = (interval.lower, interval.upper)
            let lower = switch v1 {
                case let .included(v): Limit.excluded(v)
                case let .excluded(v): Limit.included(v)
                case .unbounded: fatalError()
            }
            result.append(.init(start, lower))
            start = switch v2 {
                case let .included(v): Limit.excluded(v)
                case let .excluded(v): Limit.included(v)
                case .unbounded: .unbounded
            }
        }
        if start != .unbounded {
            result.append(VersionInterval(start, .unbounded))
        }

        return .init(segments: result)
    }

    // MARK: - Union and intersection

    public func union(_ other: VersionRange<V>) -> VersionRange<V> {
        negate().intersection(other.negate()).negate()
    }

    public func intersection(_ other: VersionRange<V>) -> VersionRange<V> {
        var output: [VersionInterval<V>] = []
        var leftIter = 0
        var rightIter = 0

        func leftPeek() -> VersionInterval<V>? {
            return self.segments[safe: leftIter]
        }
        func leftNext() -> VersionInterval<V>? {
            defer { leftIter += 1 }
            return self.segments[safe: leftIter]
        }
        func rightPeek() -> VersionInterval<V>? {
            return other.segments[safe: rightIter]
        }
        func rightNext() -> VersionInterval<V>? {
            defer { rightIter += 1 }
            return other.segments[safe: rightIter]
        }

        while let left = leftPeek(), let right = rightPeek() {
            let leftStart = left.lower
            let leftEnd = left.upper
            let rightStart = right.lower
            let rightEnd = right.upper

            let leftEndIsSmaller = leftEndIsSmaller(left: leftEnd, right: rightEnd)

            let otherStart: Limit
            let end: Limit

            if leftEndIsSmaller {
                _ = leftNext()
                otherStart = rightStart
                end = leftEnd
            } else {
                _ = rightNext()
                otherStart = leftStart
                end = rightEnd
            }

            if !validSegment(start: otherStart, end: end) {
                continue
            }

            let start: Limit

            switch (leftStart, rightStart) {
            case let (.included(l), .included(r)):
                start = .included(max(l, r))
            case let (.excluded(l), .excluded(r)):
                start = .excluded(max(l, r))

            case let (.included(i), .excluded(e)), 
                let (.excluded(e), .included(i)):
                if i <= e {
                    start = .excluded(e)
                } else {
                    start = .included(i)
                }
            case let (s, .unbounded), let (.unbounded, s):
                start = s
            }

            output.append(.init(start, end))
        }

        let result = VersionRange(segments: output)
        #if DEBUG
        result.checkInvariants()
        #endif

        return result
    }
}

extension Collection {
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
