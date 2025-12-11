import Foundation

public struct VersionInterval<V: Version>: Equatable, CustomStringConvertible {
    public var lower: V
    // interval is open if upper version is nil
    public var upper: V?

    public init(_ lower: V, _ upper: V? = nil) {
        self.lower = lower
        self.upper = upper
    }

    public var description: String {
        if let upper {
            if upper == lower.bump() {
                return "\(lower)"
            } else {
                return "[\(lower) - \(upper))"
            }
        } else {
            return "[\(lower) - any)"
        }
    }
}

public struct VersionRange<V: Version>: Equatable, CustomStringConvertible {
    public let segments: [VersionInterval<V>]

    public var description: String {
        let segmentsString = segments.map(\.description).joined(separator: ", ")
        if segments.count == 1 {
            return segmentsString
        }
        return "[\(segmentsString)]"
    }

    // MARK: - Initialization methods

    /// Empty set of versions
    public static func none() -> VersionRange<V> {
        .init(segments: [])
    }

    /// Set of all possible versions
    public static func any() -> VersionRange<V> {
        .higherThan(version: V.lowest)
    }

    /// Set of all versions higher or equal to some version
    public static func higherThan(version: V) -> VersionRange<V> {
        .init(segments: [VersionInterval(version)])
    }

    public static func exact(version: V) -> VersionRange<V> {
        .init(segments: [VersionInterval(version, version.bump())])
    }

    public static func strictlyLowerThan(version: V) -> VersionRange<V> {
        if version == V.lowest {
            return .none()
        }
        return .init(segments: [VersionInterval(V.lowest, version)])
    }

    public static func between(_ version1: V, _ version2: V) -> VersionRange<V> {
        precondition(version1 < version2)
        return .init(segments: [VersionInterval(version1, version2)])
    }

    // MARK: - Utility functions

    public func contains(_ version: V) -> Bool {
        for interval in segments {
            if let upper = interval.upper {
                if version < interval.lower {
                    return false
                } else if version < upper {
                    return true
                }
            } else {
                return interval.lower <= version
            }
        }

        return false
    }

    public func lowestVersion() -> V? {
        segments.first?.lower
    }

    // MARK: - Set operations

    // MARK: Negate

    public func negate() -> VersionRange<V> {
        guard let first = segments.first else {
            return .any()
        }

        let v = first.lower

        if let v2 = first.upper {
            if v == V.lowest {
                return VersionRange.negateSegments(start: v2, segments: Array(segments[1...]))
            } else {
                return VersionRange.negateSegments(start: V.lowest, segments: segments)
            }
        } else {
            if v == V.lowest {
                return .none()
            } else {
                return .strictlyLowerThan(version: v)
            }
        }
    }

    static func negateSegments(start: V, segments: [VersionInterval<V>]) -> VersionRange<V> {
        var complementSegments: [VersionInterval<V>] = []
        var start: V? = start

        for interval in segments {
            let (v1, maybeV2) = (interval.lower, interval.upper)
            complementSegments.append(.init(start!, v1))
            start = maybeV2
        }
        if let last = start {
            complementSegments.append(VersionInterval(last))
        }

        return .init(segments: complementSegments)
    }

    // MARK: - Union and intersection

    public func union(_ other: VersionRange<V>) -> VersionRange<V> {
        negate().intersection(other.negate()).negate()
    }

    public func intersection(_ other: VersionRange<V>) -> VersionRange<V> {
        var segments: [VersionInterval<V>] = []
        var leftIter = 0
        var rightIter = 0

        func leftNext() -> VersionInterval<V>? {
            defer { leftIter += 1 }
            return self.segments[safe: leftIter]
        }
        func rightNext() -> VersionInterval<V>? {
            defer { rightIter += 1 }
            return other.segments[safe: rightIter]
        }

        var left = leftNext()
        var right = rightNext()

        outer: while true {
            switch (left?.lower, left?.upper, right?.lower, right?.upper) {
            // Both left and right contain finite interval
            case let (.some(l1), .some(l2), .some(r1), .some(r2)):
                if l2 <= r1 {
                    // Intervals are disjoint, progress on the left.
                    left = leftNext()
                } else if r2 <= l1 {
                    // Intervals are disjoint, progress on the right.
                    right = rightNext()
                } else {
                    // Intervals are not disjoint.
                    let start = max(l1, r1)
                    if l2 < r2 {
                        segments.append(VersionInterval(start, l2))
                        left = leftNext()
                    } else {
                        segments.append(VersionInterval(start, r2))
                        right = rightNext()
                    }
                }
            case let (.some(l1), .some(l2), .some(r1), nil):
                if l2 < r1 {
                    // Less
                    left = leftNext()
                } else if l2 == r1 {
                    // Equals
                    while let l = leftNext() {
                        segments.append(l)
                    }
                    break outer
                } else {
                    // Greater
                    let start = max(l1, r1)
                    segments.append(VersionInterval(start, l2))
                    while let l = leftNext() {
                        segments.append(l)
                    }
                    break outer
                }

            // Left side contains infinite interval
            case let (.some(l1), nil, .some(r1), .some(r2)):
                if r2 < l1 {
                    right = rightNext()
                } else if r2 == l1 {
                    while let r = rightNext() {
                        segments.append(r)
                    }
                    break outer
                } else {
                    let start = max(l1, r1)
                    segments.append(VersionInterval(start, r2))
                    while let r = rightNext() {
                        segments.append(r)
                    }
                    break outer
                }

            // Both sides contain infinite interval
            case let (.some(l1), nil, .some(r1), nil):
                let start = max(l1, r1)
                segments.append(VersionInterval(start))
                break outer

            // Left or right has ended
            default:
                break outer
            }
        }

        return VersionRange(segments: segments)
    }
}

extension Collection {
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension VersionRange {}
