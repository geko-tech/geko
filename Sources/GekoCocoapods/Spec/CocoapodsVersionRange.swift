import Foundation

public enum CocoapodsVersionRange: Equatable {
    case any
    case exact(CocoapodsVersion)
    case higherThan(CocoapodsVersion)
    case strictlyLessThan(CocoapodsVersion)
    case between(CocoapodsVersion, CocoapodsVersion)

    private static let quantifierCharset: CharacterSet = {
        var charset = CharacterSet()
        charset.insert(charactersIn: "~><=")
        return charset
    }()

    private static let otherCharset: CharacterSet = {
        var charset = CharacterSet()
        charset.formUnion(CocoapodsVersion.versionCharset)
        charset.formUnion(quantifierCharset)
        charset.invert()
        return charset
    }()
}

public enum CocoapodsVersionRangeError: Error, CustomStringConvertible {
    case invalidVersionRangeString(String)
    case unsupportedVersionRangeString(String)

    public var description: String {
        switch self {
        case let .invalidVersionRangeString(str):
            return "invalid version string '\(str)'"
        case let .unsupportedVersionRangeString(str):
            return "unsupported version range string '\(str)'"
        }
    }
}

extension CocoapodsVersionRange {
    public static func components(from versionRange: String) -> [Substring] {
        var result: [Substring] = []

        var idx = versionRange.startIndex

        while idx < versionRange.endIndex {
            guard versionRange[idx].unicodeScalars.count == 1 else {
                idx = versionRange.index(after: idx)
                continue
            }

            var newIdx = idx
            if CocoapodsVersion.versionCharset.contains(versionRange[idx].unicodeScalars.first!) {
                newIdx = versionRange.idxWhile(idx: idx, charset: CocoapodsVersion.versionCharset)
                result.append(versionRange[idx..<newIdx])
            } else if quantifierCharset.contains(versionRange[idx].unicodeScalars.first!) {
                newIdx = versionRange.idxWhile(idx: idx, charset: quantifierCharset)
                result.append(versionRange[idx..<newIdx])
            } else {
                while newIdx < versionRange.endIndex, otherCharset.contains(versionRange[newIdx].unicodeScalars.first!) {
                    newIdx = versionRange.index(after: newIdx)
                }
            }

            idx = newIdx
        }

        return result
    }

    public static func from(_ components: [String]) throws -> CocoapodsVersionRange {
        if components.count < 1 {
            return .any
        }

        if components.count > 2 {
            throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
        }

        let (quantifier, lower, upper) = try component(from: components[0])

        switch quantifier {
        case .unknown:
            throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))

        case .exact:
            guard components.count == 1, let lower else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }
            return .exact(lower)

        case .optimistic:
            guard let lower else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }
            if let upper {
                return .between(lower, upper)
            } else {
                return .higherThan(lower)
            }

        case .lessThan:
            guard let upper else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }

            if components.count == 1 {
                return .strictlyLessThan(upper)
            }

            let (secondQuantifier, secondLower, _) = try component(from: components[1])

            guard secondQuantifier == .greaterThan, let secondLower, secondLower < upper else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }

            return .between(secondLower, upper)

        case .greaterThan:
            guard let lower else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }

            if components.count == 1 {
                return .higherThan(lower)
            }

            let (secondQuantifier, _, secondUpper) = try component(from: components[1])

            guard secondQuantifier == .lessThan, let secondUpper, lower < secondUpper else {
                throw CocoapodsVersionRangeError.invalidVersionRangeString(components.joined(separator: ","))
            }

            return .between(lower, secondUpper)
        }
    }

    private enum VersionQuantifier {
        case optimistic  // ~>
        case greaterThan  // >=
        case lessThan  // <
        case exact  // =
        case unknown
    }

    private static func component(from string: String) throws -> (VersionQuantifier, lower: CocoapodsVersion?, upper: CocoapodsVersion?) {
        let components = components(from: string)

        switch components.count {
        case 1:
            // exact version
            let exactVersion = CocoapodsVersion(from: components[0])
            return (.exact, exactVersion, nil)
        case 2:
            let clearVersion = components[1].split(separator: "-")[0]

            let versionSegmentsCount = CocoapodsVersion.versionSegments(String(clearVersion)).count
            let version: CocoapodsVersion = .init(from: clearVersion)
            let potentialMaxVersion: CocoapodsVersion?

            assert(CocoapodsVersion.maxSegmentCount == 5)
            switch versionSegmentsCount {
            case 1:
                potentialMaxVersion = nil
            case 2:
                potentialMaxVersion = .init(version.major + 1)
            case 3:
                potentialMaxVersion = .init(version.major, version.minor + 1)
            case 4:
                potentialMaxVersion = .init(
                    version.major, version.minor, version.patch + 1
                )
            case 5:
                potentialMaxVersion = .init(
                    version.major, version.minor, version.patch, version.segment4 + 1
                )
            default:
                throw CocoapodsVersionRangeError.invalidVersionRangeString(string)
            }
            switch components[0] {
            case "~>":
                return (.optimistic, version, potentialMaxVersion)
            case ">=":
                return (.greaterThan, version, nil)
            case "=":
                return (.exact, version, nil)
            case "<":
                return (.lessThan, nil, version)
            default:
                return (.unknown, nil, nil)
            }
        default:
            throw CocoapodsVersionRangeError.invalidVersionRangeString(string)
        }
    }
}

extension String {
    fileprivate func idxWhile(idx: String.Index, charset: CharacterSet) -> String.Index {
        var newIdx = idx

        while newIdx < endIndex, charset.contains(self[newIdx].unicodeScalars.first!) {
            newIdx = index(after: newIdx)
        }

        return newIdx
    }
}
