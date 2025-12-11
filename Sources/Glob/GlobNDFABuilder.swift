// transition, that requires more than 1 state or has a loopback
struct CachedSpecialTransition: Hashable {
    enum TransitionType {
        case recursiveDescent // '**'
        case anyPathPart // '*'
    }

    let from: UInt16
    let type: TransitionType
}

struct CachedTransition: Hashable {
    let from: UInt16
    let type: GlobStateTransitionType
}

struct StatePointer: Hashable {
    // index in states array
    let idx: UInt16
    // additional flags associated with this instance of pointer
    var flags: Flags

    struct Flags: OptionSet, Hashable {
        var rawValue: UInt8

        static let empty: Flags = []

        static let slash = Flags(rawValue: 1)
        static let recursive = Flags(rawValue: 1 << 1)
        static let potentialRecursive = Flags(rawValue: 1 << 2)
        static let potentialAsterisk = Flags(rawValue: 1 << 3)
        static let potentialRecursiveOrAsterisk = Flags(rawValue: 1 << 4)
    }

    init(idx: UInt16, flags: Flags = .empty) {
        self.idx = idx
        self.flags = flags
    }
}

struct GlobNDFABuilder {
    var states: [GlobNDFAState]
    var pattern: [UInt8]

    var statesStack: [(startingStates: [StatePointer], trailingStates: [StatePointer])]

    // for recursive descent values are (loopIdx, endIdx, connected)
    // for path part values are (endIdx, 0, connected)
    var specialTransitionsCache: [CachedSpecialTransition: (UInt16, UInt16, Bool)] = [:]
    // values are (stateIdx, connected)
    var transitionsCache: [CachedTransition: (UInt16, Bool)] = [:]

    init(pattern: [UInt8]) {
        self.states = [.empty]
        statesStack = [([.init(idx: 0)], [.init(idx: 0)])]
        self.pattern = pattern
    }

    var trailingStates: [StatePointer] {
        get {
            return statesStack[statesStack.count - 1].trailingStates
        }
        set {
            statesStack[statesStack.count - 1].trailingStates = newValue
        }
    }

    var startingStates: [StatePointer] {
        return statesStack[statesStack.count - 1].startingStates
    }

    mutating func pushEmptyState() -> UInt16 {
        states.append(.empty)
        return UInt16(states.count - 1)
    }

    mutating func addTransition(_ type: GlobStateTransitionType, from: UInt16, to: UInt16) {
        states[Int(from)].transitions.append(.init(type: type, stateIdx: to))
    }

    // '*'
    mutating func pushAnyPathPart(from: UInt16) -> UInt16 {
        let cacheKey = CachedSpecialTransition(from: from, type: .anyPathPart)

        if let (cached, _, connected) = specialTransitionsCache[cacheKey] {
            if !connected {
                addTransition(.epsilon, from: from, to: cached)
                specialTransitionsCache[cacheKey] = (cached, 0, true)
            }

            return cached
        }

        let newStateIdx = pushEmptyState()

        addTransition(.epsilon, from: from, to: newStateIdx)
        addTransition(.anyExceptSlash, from: newStateIdx, to: newStateIdx)

        specialTransitionsCache[cacheKey] = (newStateIdx, 0, true)

        for statePointer in trailingStates {
            guard statePointer.idx != from else { continue }
            specialTransitionsCache[.init(from: statePointer.idx, type: .anyPathPart)]
                = (newStateIdx, 0, false)
        }

        return newStateIdx
    }

    // '**'
    mutating func pushRecursiveDescent(from: UInt16) -> (UInt16, UInt16) {
        let cacheKey = CachedSpecialTransition(from: from, type: .recursiveDescent)

        if let (cachedLoop, cachedExit, connected) = specialTransitionsCache[cacheKey] {
            if !connected {
                addTransition(.epsilon, from: from, to: cachedLoop)
                addTransition(.epsilon, from: from, to: cachedExit)
                specialTransitionsCache[cacheKey] = (cachedLoop, cachedExit, true)
            }

            return (cachedLoop, cachedExit)
        }

        let loopIdx = pushEmptyState()
        addTransition(.epsilon, from: from, to: loopIdx)
        addTransition(.any, from: loopIdx, to: loopIdx)

        let endIdx = pushEmptyState()
        addTransition(.epsilon, from: from, to: endIdx)
        addTransition(.slash, from: loopIdx, to: endIdx)

        specialTransitionsCache[cacheKey] = (loopIdx, endIdx, true)
        specialTransitionsCache[.init(from: endIdx, type: .recursiveDescent)] = (loopIdx, endIdx, true)

        for statePointer in trailingStates {
            guard statePointer.idx != from else { continue }
            specialTransitionsCache[.init(from: statePointer.idx, type: .recursiveDescent)]
                = (loopIdx, endIdx, false)
        }

        return (loopIdx, endIdx)
    }

    mutating func pushState(from: StatePointer, transition: GlobStateTransitionType) -> UInt16 {
        var fromIdx = from.idx

        if from.flags.contains(.potentialRecursiveOrAsterisk) ||
            from.flags.contains(.potentialAsterisk) ||
            from.flags.contains(.potentialRecursive) {
            fromIdx = pushAnyPathPart(from: from.idx)
        }

        let cacheKey = CachedTransition(from: fromIdx, type: transition)

        if let (cached, connected) = transitionsCache[cacheKey] {
            if !connected {
                self.addTransition(transition, from: fromIdx, to: cached)
                transitionsCache[cacheKey] = (cached, true)
            }
            return cached
        }

        let newStateIdx = pushEmptyState()
        addTransition(transition, from: fromIdx, to: newStateIdx)

        transitionsCache[cacheKey] = (newStateIdx, true)

        for statePointer in trailingStates {
            guard statePointer.idx != fromIdx else { continue }
            transitionsCache[.init(from: statePointer.idx, type: transition)] = (newStateIdx, false)
        }

        return newStateIdx
    }

    mutating func pushState(transition: GlobStateTransitionType) {
        var newStates: Set<StatePointer> = []

        for stateIdx in trailingStates {
            let newState = pushState(from: stateIdx, transition: transition)
            newStates.insert(.init(idx: newState))
        }

        trailingStates = Array(newStates)
    }

    mutating func pushSlash() {
        var newTrailingStates: [StatePointer] = []

        for previousStatePointer in trailingStates {
            if previousStatePointer.flags.contains(.potentialAsterisk) || previousStatePointer.flags.contains(.potentialRecursiveOrAsterisk) {
                let slashIdx = pushState(from: previousStatePointer, transition: .slash)
                newTrailingStates.append(.init(idx: slashIdx, flags: .slash))
                continue
            }

            if previousStatePointer.flags.contains(.potentialRecursive) {
                if previousStatePointer.flags.contains(.recursive) {
                    var newPointer = previousStatePointer
                    newPointer.flags.remove(.potentialRecursive)
                    newTrailingStates.append(newPointer)
                    continue
                }
                let (_, endIdx) = pushRecursiveDescent(from: previousStatePointer.idx)
                newTrailingStates.append(.init(idx: endIdx, flags: [.recursive, .slash]))
                continue
            }

            if previousStatePointer.flags.contains(.slash) {
                continue
            }

            let slashIdx = pushState(from: previousStatePointer, transition: .slash)
            newTrailingStates.append(.init(idx: slashIdx, flags: .slash))
        }

        if !newTrailingStates.isEmpty {
            trailingStates = Array(Set(newTrailingStates))
        }
    }

    mutating func pushAsterisk() {
        var newTrailingStates: Set<StatePointer> = []

        for var statePointer in trailingStates {

            if statePointer.flags.contains(.potentialAsterisk) {
                // do nothing
            } else if statePointer.flags.contains(.potentialRecursive) {
                statePointer.flags.remove(.potentialRecursive)
                statePointer.flags.insert(.potentialAsterisk)
            } else if statePointer.flags.contains(.potentialRecursiveOrAsterisk) && statePointer.flags.contains(.slash) {
                statePointer.flags.remove(.potentialRecursiveOrAsterisk)
                statePointer.flags.insert(.potentialRecursive)
            } else if statePointer.flags.contains(.slash) {
                statePointer.flags.insert(.potentialRecursiveOrAsterisk)
            } else {
                statePointer.flags.insert(.potentialAsterisk)
            }

            newTrailingStates.insert(statePointer)
        }

        trailingStates = Array(newTrailingStates)
    }

    mutating func startAlteration() {
        let previousTrailingStates = trailingStates
        statesStack.append((previousTrailingStates, previousTrailingStates))
        statesStack[statesStack.count - 2].trailingStates = []
    }

    mutating func switchAlteration() throws {
        guard statesStack.count > 1 else {
            throw GlobNDFAError.commaOutsideOfBraces
        }

        statesStack[statesStack.count - 2].trailingStates.append(contentsOf: trailingStates)
        trailingStates = startingStates
    }

    mutating func endAlteration() throws {
        guard statesStack.count > 1 else {
            throw GlobNDFAError.unbalancedBraces
        }

        statesStack[statesStack.count - 2].trailingStates.append(contentsOf: trailingStates)
        statesStack.removeLast()
    }

    mutating func flattenEpsilonTransitions() {
        var stack: [(stateIdx: UInt16, stage: UInt8)] = [(0, 0)]
        var seenStates: Set<UInt16> = []

        while !stack.isEmpty {
            let (stateIdx, stage) = stack.removeLast()

            if stage == 0 {
                seenStates.insert(stateIdx)
                stack.append((stateIdx, 1))

                states[stateIdx].transitions.forEach { transition in
                    guard !seenStates.contains(transition.stateIdx) else { return }
                    stack.append((transition.stateIdx, 0))
                }
            } else if stage == 1 {
                states[stateIdx].transitions.forEach { transition in
                    guard case .epsilon = transition.type else { return }

                    states[transition.stateIdx].transitions.forEach { transitiveTransition in
                        guard case .epsilon = transitiveTransition.type else { return }
                        states[stateIdx].transitions.append(transitiveTransition)
                    }
                }
            }
        }
    }

    static func parseSet(buf: [UInt8], pos: Int) throws -> (GlobStateTransitionType?, processedBytes: Int) {
        let bufSize = buf.count
        var bufPos = pos
        bufPos += 1

        var negated = false

        if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
        var char = buf[bufPos]

        if char == .exclamationMark {
            negated = true
            bufPos += 1
            if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
            char = buf[bufPos]
        }

        if char == .backslash {
            bufPos += 1
            if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
            char = buf[bufPos]
        } else if char == .closingBracket {
            bufPos += 1
            // empty set
            return (nil, bufPos - pos)
        }

        let firstCodepointChar = char
        let firstCodepointPos = bufPos
        let firstCodepointLength = Int(utf8CodepointLengthTable[Int(char)])
        if firstCodepointLength == 0 { throw GlobNDFAError.invalidUtf8 }

        bufPos += Int(firstCodepointLength)
        if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
        char = buf[bufPos]

        if char == .closingBracket {
            // single character set
            bufPos += 1

            let transition: GlobStateTransitionType
            if firstCodepointLength == 1 {
                if negated {
                    transition = .notAscii(char)
                } else {
                    transition = .ascii(char)
                }
            } else {
                if negated {
                    transition = .notUtf8(UInt16(firstCodepointPos))
                } else {
                    transition = .utf8(UInt16(firstCodepointPos))
                }
            }

            return (transition, bufPos - pos)
        }

        if char == .hyphen {
            // character range
            bufPos += 1
            if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
            char = buf[bufPos]

            if char == .backslash {
                bufPos += 1
                if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
                char = buf[bufPos]
            }

            let secondCodepointChar = char
            let secondCodepointLength = Int(utf8CodepointLengthTable[Int(char)])
            if secondCodepointLength == 0 { throw GlobNDFAError.invalidUtf8 }
            bufPos += Int(secondCodepointLength)
            if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
            char = buf[bufPos]

            if char != .closingBracket { throw GlobNDFAError.unbalancedBrackets }
            bufPos += 1

            if firstCodepointLength != secondCodepointLength {
                let range = String(bytes: buf[pos..<bufPos], encoding: .utf8)
                throw GlobNDFAError.differentCodepointLengthInRange(range ?? "")
            }

            let transition: GlobStateTransitionType
            if firstCodepointLength == 1 {
                if negated {
                    transition = .notAsciiRange(firstCodepointChar, secondCodepointChar)
                } else {
                    transition = .asciiRange(firstCodepointChar, secondCodepointChar)
                }
            } else {
                if negated {
                    transition = .notUtf8Range(UInt16(firstCodepointPos))
                } else {
                    transition = .utf8Range(UInt16(firstCodepointPos))
                }
            }
            return (transition, bufPos - pos)
        }

        while bufPos < bufSize {
            char = buf[bufPos]

            if char == .backslash {
                bufPos += 1
                if bufPos >= bufSize { throw GlobNDFAError.unbalancedBrackets }
                char = buf[bufPos]
            } else if char == .closingBracket {
                bufPos += 1
                if negated {
                    return (.notSet(UInt16(firstCodepointPos)), bufPos - pos)
                } else {
                    return (.set(UInt16(firstCodepointPos)), bufPos - pos)
                }
            }

            let codepointLength = utf8CodepointLengthTable[Int(char)]
            bufPos += Int(codepointLength)
        }

        throw GlobNDFAError.unbalancedBrackets
    }

    static func build(globPattern: String) throws -> GlobNDFA {
        let buf: [UInt8] = Array(globPattern.utf8)
        var builder = GlobNDFABuilder(pattern: buf)

        var bufPos = 0
        let bufSize = buf.count

        builder.pushSlash()

        loop: while bufPos < bufSize {
            var char = buf[Int(bufPos)]

            switch char {
            case .openingBrace:
                bufPos += 1

                // skip empty alterations
                while bufPos < bufSize, buf[bufPos] == .comma {
                    bufPos += 1
                }

                if bufPos < bufSize, buf[bufPos] == .closingBrace {
                    bufPos += 1
                    // empty alteration set
                    continue
                }

                builder.startAlteration()

            case .comma:
                bufPos += 1

                // skip empty alterations
                while bufPos < bufSize, buf[bufPos] == .comma {
                    bufPos += 1
                }

                if bufPos < bufSize, buf[bufPos] == .closingBrace {
                    bufPos += 1
                    // encountered '}', no need to start another alteration
                    try builder.endAlteration()
                }

                try builder.switchAlteration()

            case .closingBrace:
                bufPos += 1
                try builder.endAlteration()

            case .slash:
                bufPos += 1
                builder.pushSlash()

            case .asterisk:
                bufPos += 1
                builder.pushAsterisk()

            case .questionMark:
                bufPos += 1
                builder.pushState(transition: .anyExceptSlash)

            case .openingBracket:
                let (transition, processedBytes) = try parseSet(buf: buf, pos: bufPos)
                bufPos += processedBytes
                if let transition {
                    builder.pushState(transition: transition)
                }

            case .closingBracket:
                throw GlobNDFAError.unbalancedBrackets

            case .backslash:
                bufPos += 1
                if bufPos < bufSize {
                    char = buf[bufPos]
                    fallthrough
                } else {
                    throw GlobNDFAError.backslashNothing
                }
            default:
                let codepointLength = utf8CodepointLengthTable[Int(char)]
                let transition: GlobStateTransitionType
                switch codepointLength {
                case 0:
                    throw GlobNDFAError.invalidUtf8
                case 1:
                    // ascii characters are stored inline since
                    // they occupy 1 byte of memory
                    transition = .ascii(char)
                default:
                    transition = .utf8(UInt16(bufPos))
                }
                bufPos += Int(codepointLength)
                builder.pushState(transition: transition)
            }
        }

        if builder.statesStack.count > 1 {
            throw GlobNDFAError.unbalancedBraces
        }

        builder.pushSlash()
        for trailingStatePointer in builder.trailingStates {
            builder.states[trailingStatePointer.idx].isMatch = true
        }

        builder.flattenEpsilonTransitions()

        return GlobNDFA(states: builder.states, pattern: buf)
    }
}
