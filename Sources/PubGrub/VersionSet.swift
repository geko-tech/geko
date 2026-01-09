public struct VersionSet<V: Version>: Equatable {
    public let release: VersionRange<V>
    public let preRelease: VersionRange<V>

    public init(release: VersionRange<V>, preRelease: VersionRange<V>) {
        self.release = release
        self.preRelease = preRelease
    }

    public func contains(_ version: V) -> Bool {
        if version.isPreRelease {
            return preRelease.contains(version)
        } else {
            return release.contains(version)
        }
    }

    public func intersection(_ other: VersionSet<V>) -> VersionSet<V> {
        return VersionSet(
            release: self.release.intersection(other.release),
            preRelease: self.preRelease.intersection(other.preRelease)
        )
    }

    public func union(_ other: VersionSet<V>) -> VersionSet<V> {
        return VersionSet(
            release: self.release.union(other.release),
            preRelease: self.preRelease.union(other.preRelease)
        )
    }

    public func negate() -> VersionSet<V> {
        return VersionSet(
            release: self.release.negate(),
            preRelease: self.preRelease.negate()
        )
    }
}

// MARK: - Convenience methods

extension VersionSet {
    public static func none() -> VersionSet<V> {
        .init(release: .none(), preRelease: .none())
    }

    public static func any() -> VersionSet<V> {
        return VersionSet(
            release: .any(),
            preRelease: .any()
        )
    }

    public static func exact(version: V) -> VersionSet<V> {
        if version.isPreRelease {
            return VersionSet(
                release: .none(),
                preRelease: .exact(version: version)
            )
        } else {
            return VersionSet(
                release: .exact(version: version),
                preRelease: .none()
            )
        }
    }
}
