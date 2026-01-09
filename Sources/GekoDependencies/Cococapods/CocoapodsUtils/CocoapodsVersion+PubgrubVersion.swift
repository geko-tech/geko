import PubGrub
import GekoCocoapods

extension CocoapodsVersion: PubGrub.Version {
    public var isPreRelease: Bool {
        return preRelease != nil || !preReleaseSegments.isEmpty
    }

    public func asReleaseVersion() -> CocoapodsVersion {
        assert(CocoapodsVersion.maxSegmentCount == 5)

        return CocoapodsVersion(
            max(0, self.major),
            max(0, self.minor),
            max(0, self.patch),
            max(0, self.segment4),
            max(0, self.segment5)
        )
    }

    public func withEmptyPreRelease() -> CocoapodsVersion {
        assert(CocoapodsVersion.maxSegmentCount == 5)

        return CocoapodsVersion(
            max(0, self.major),
            max(0, self.minor),
            max(0, self.patch),
            max(0, self.segment4),
            max(0, self.segment5),
            // empty pre-release is used because empty string is smallest of all strings
            // so it is considered smallest pre-release
            preRelease: ""
        )
    }
}
