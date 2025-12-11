public final class GlobTreeTraverser {
    public let globSet: GlobSet
    public var globSetStateStack: [GlobSetState]

    var globSetState: GlobSetState { return globSetStateStack[globSetStateStack.count - 1] }

    public init(_ include: [String], exclude: [String] = []) throws {
        self.globSet = try GlobSet(include, exclude: exclude)
        self.globSetStateStack = [
            .init(includeGlobsCount: include.count, excludeGlobsCount: exclude.count)
        ]

        globSet.prepareForTreeTraversal(state: &globSetStateStack[0])
    }

    public func match(filename: String) -> Bool {
        var newGlobSetState = self.globSetState

        let (fullMatch, _) = globSet.process(pathPart: filename, with: &newGlobSetState)

        return fullMatch
    }

    public func descend(into dirname: String) -> (shouldDescend: Bool, match: Bool) {
        var newGlobSetState = self.globSetState

        let (fullMatch, partialMatch) = globSet.process(pathPart: dirname, with: &newGlobSetState)

        if partialMatch {
            globSetStateStack.append(newGlobSetState)
        }

        return (partialMatch, fullMatch)
    }

    public func ascend() {
        globSetStateStack.removeLast()
    }

    public static func basePath(for globPatterns: [String]) -> String {
        if globPatterns.count == 0 { return "" }

        var buffers: [[UInt8]] = []

        for pattern in globPatterns {
            buffers.append(Array(pattern.utf8))
        }

        var maxSize = Int.max
        for i in 0 ..< buffers.count {
            maxSize = min(maxSize, buffers[i].count)
        }

        var lastSlashPosition = 0
        var treatCharLiterally = false

        outer: for i in 0 ..< maxSize {
            let ch = buffers[0][i]

            for bufIdx in 1 ..< buffers.count {
                guard buffers[bufIdx][i] == ch else { break outer }
            }

            if treatCharLiterally {
                treatCharLiterally = false
                continue
            }

            switch ch {
            case .slash:
                lastSlashPosition = i
            case .backslash:
                treatCharLiterally = true
            case .asterisk, .openingBrace, .closingBrace, .openingBracket, .closingBracket, .questionMark:
                break outer
            default:
                break
            }
        }

        let result = String(bytes: buffers[0][0..<lastSlashPosition], encoding: .utf8) ?? ""
        return result.isEmpty ? "/" : result
    }
}
