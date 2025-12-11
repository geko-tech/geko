public struct GlobSetState {
    var includeGlobStates: [GlobState]
    var excludeGlobStates: [GlobState]

    init(includeGlobsCount: Int, excludeGlobsCount: Int) {
        var includeGlobStates: [GlobState] = []
        includeGlobStates.reserveCapacity(includeGlobsCount)
        var excludeGlobStates: [GlobState] = []
        excludeGlobStates.reserveCapacity(includeGlobsCount)

        for _ in 0 ..< includeGlobsCount {
            includeGlobStates.append(.init(currentNdfaStates: [0]))
        }
        for _ in 0 ..< excludeGlobsCount {
            excludeGlobStates.append(.init(currentNdfaStates: [0]))
        }

        self.includeGlobStates = includeGlobStates
        self.excludeGlobStates = excludeGlobStates
    }
}

public struct GlobSet {
    let includeGlobs: [Glob]
    let excludeGlobs: [Glob]

    public init(_ include: [String], exclude: [String] = []) throws {
        var includeGlobs: [Glob] = []
        for glob in include {
            do {
                includeGlobs.append(try Glob(glob))
            } catch let error as GlobNDFAError {
                throw GlobSetError.globError(pattern: glob, error: error)
            }
        }

        var excludeGlobs: [Glob] = []
        for glob in exclude {
            do {
                excludeGlobs.append(try Glob(glob))
            } catch let error as GlobNDFAError {
                throw GlobSetError.globError(pattern: glob, error: error)
            }
        }

        self.includeGlobs = includeGlobs
        self.excludeGlobs = excludeGlobs
    }

    public func match(string: String) -> Bool {
        var includeMatch = false
        var excludeMatch = false

        for includeGlob in includeGlobs {
            if includeGlob.match(string: string) {
                includeMatch = true
                break
            }
        }
        for excludeGlob in excludeGlobs {
            if excludeGlob.match(string: string) {
                excludeMatch = true
                break
            }
        }

        return includeMatch && !excludeMatch
    }

    func prepareForTreeTraversal(state: inout GlobSetState) {
        for i in 0 ..< includeGlobs.count {
            includeGlobs[i].addSlash(to: &state.includeGlobStates[i])
        }
        for i in 0 ..< excludeGlobs.count {
            excludeGlobs[i].addSlash(to: &state.excludeGlobStates[i])
        }
    }

    func process(pathPart: String, with state: inout GlobSetState) -> (fullMatch: Bool, partialMatch: Bool) {
        var pathPart = pathPart
        return pathPart.withUTF8 { buffer in
            var includePartialMatch = false
            var includeFullMatch = false
            var excludeFullMatch = false

            for globIdx in 0 ..< includeGlobs.count {
                includeGlobs[globIdx]
                    .process(buffer: buffer, using: &state.includeGlobStates[globIdx])
                includeGlobs[globIdx].addSlash(to: &state.includeGlobStates[globIdx])
                includeGlobs[globIdx].processEpsilonTransitions(in: &state.includeGlobStates[globIdx])
                let (fullMatch, partialMatch) = includeGlobs[globIdx]
                    .checkMatch(in: &state.includeGlobStates[globIdx])

                includePartialMatch = partialMatch || includePartialMatch
                includeFullMatch = fullMatch || includeFullMatch
            }
            for globIdx in 0 ..< excludeGlobs.count {
                excludeGlobs[globIdx]
                    .process(buffer: buffer, using: &state.excludeGlobStates[globIdx])
                excludeGlobs[globIdx].addSlash(to: &state.excludeGlobStates[globIdx])
                excludeGlobs[globIdx].processEpsilonTransitions(in: &state.excludeGlobStates[globIdx])
                let (fullMatch, _) = excludeGlobs[globIdx]
                    .checkMatch(in: &state.excludeGlobStates[globIdx])

                excludeFullMatch = excludeFullMatch || fullMatch
            }

            if excludeFullMatch {
                return (false, false)
            }

            return (includeFullMatch, includePartialMatch)
        }
    }

    public func isExcluded(_ string: String) -> Bool {
        for excludeGlob in excludeGlobs {
            if excludeGlob.match(string: string) {
                return true
            }
        }

        return false
    }
}
