import Foundation

extension Array {
    subscript(_ idx: UInt16) -> Element {
        get {
            return self[Int(idx)]
        }
        set {
            self[Int(idx)] = newValue
        }
    }
}

let utf8CodepointLengthTable: [UInt8] = [
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 0xxxxxxx
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 10xxxxxx
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 110xxxxx
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, // 1110xxxx
    4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 0, 0,
]

private let maxPatternSize: Int = Int(UInt16.max >> 1)

extension UInt8 {
    static let exclamationMark: UInt8 = 33 // '!'
    static let asterisk: UInt8 = 42 // '*'
    static let comma: UInt8 = 44 // ','
    static let hyphen: UInt8 = 45 // '-'
    static let slash: UInt8 = 47 // '/'
    static let questionMark: UInt8 = 63 // '?'
    static let openingBracket: UInt8 = 91 // '['
    static let backslash: UInt8 = 92 // '\'
    static let closingBracket: UInt8 = 93 // ']'
    static let openingBrace: UInt8 = 123 // '{'
    static let closingBrace: UInt8 = 125 // '}'

    // other characters are treated literally
}

// MARK: - NDFA

enum GlobStateTransitionType: Hashable {
    case epsilon
    case any
    case anyExceptSlash
    case slash

    /// ascii symbols, stored inline
    case ascii(UInt8)
    /// utf8 symbols with more than 2 bytes, stored by index in `pattern` array of bytes in `GlobNDFA` struct
    case utf8(UInt16)

    case notAscii(UInt8) /// [!a]
    case notUtf8(UInt16) /// [!я]

    case asciiRange(UInt8, UInt8) /// [a-z]
    case utf8Range(UInt16) /// [а-я]
    case notAsciiRange(UInt8, UInt8) /// [!a-z]
    case notUtf8Range(UInt16) /// [!а-я]

    case set(UInt16) /// [abc]
    case notSet(UInt16) /// [!abc]
}

struct GlobStateTransition: Hashable {
    var type: GlobStateTransitionType
    var stateIdx: UInt16
}

enum GlobNDFAStateTransitions {
    case empty
    case one(GlobStateTransition)
    case two(GlobStateTransition, GlobStateTransition)
    case three(GlobStateTransition, GlobStateTransition, GlobStateTransition)
    case many([GlobStateTransition])

    mutating func append(_ transition: GlobStateTransition) {
        switch self {
        case .empty:
            self = .one(transition)
        case let .one(first):
            self = .two(first, transition)
        case let .two(first, second):
            self = .three(first, second, transition)
        case let .three(first, second, third):
            self = .many([first, second, third, transition])
        case .many(var array):
            array.append(transition)
            self = .many(array)
        }
    }

    func forEach(_ closure: (GlobStateTransition) -> Void) {
        switch self {
        case .empty:
            break
        case let .one(first):
            closure(first)
        case let .two(first, second):
            closure(first)
            closure(second)
        case let .three(first, second, third):
            closure(first)
            closure(second)
            closure(third)
        case let .many(arr):
            arr.forEach(closure)
        }
    }
}

struct GlobNDFAState {
    var transitions: GlobNDFAStateTransitions
    var isMatch: Bool

    init(transitions: GlobNDFAStateTransitions = .empty, isMatch: Bool = false) {
        self.transitions = transitions
        self.isMatch = isMatch
    }

    static let empty = GlobNDFAState()
}

// non-deterministic finite automata
struct GlobNDFA {
    let states: [GlobNDFAState]
    let pattern: [UInt8]
}

struct GlobState {
    var currentNdfaStates: Set<UInt16> = []
    var tmpStates: Set<UInt16> = []
}

public struct Glob {
    let ndfa: GlobNDFA

    init(ndfa: GlobNDFA) {
        self.ndfa = ndfa
    }

    // returns 1 if codepoint from buffer is greater than codepoint in pattern
    // 0 if equal
    // -1 if less
    @inline(__always)
    fileprivate func compareUtf8Codepoints(buffer: UnsafeBufferPointer<UInt8>, bufPos: Int, patternPos: Int, codepointLength: Int) -> Int {
        var i = 0
        while i < codepointLength {
            let bufByte = buffer[bufPos + i]
            let patternByte = ndfa.pattern[patternPos + i]
            if bufByte != patternByte {
                return bufByte > patternByte ? 1 : -1
            }
            i += 1
        }

        return 0
    }

    func processEpsilonTransitions(in state: inout GlobState) {
        state.tmpStates.removeAll(keepingCapacity: true)
        state.tmpStates.formUnion(state.currentNdfaStates)
        for stateIdx in state.currentNdfaStates {
            ndfa.states[stateIdx].transitions.forEach { transition in
                if case .epsilon = transition.type {
                    state.tmpStates.insert(transition.stateIdx)
                }
            }
        }
        swap(&state.currentNdfaStates, &state.tmpStates)
    }

    func addSlash(to state: inout GlobState) {
        processEpsilonTransitions(in: &state)

        state.tmpStates.removeAll(keepingCapacity: true)
        for stateIdx in state.currentNdfaStates {
            ndfa.states[stateIdx].transitions.forEach { transition in
                switch transition.type {
                case .any, .slash:
                    break
                case .epsilon, .anyExceptSlash, .ascii, .utf8,
                     .notAscii, .notUtf8, .asciiRange, .utf8Range,
                     .notAsciiRange, .notUtf8Range, .set, .notSet:
                    return
                }
                state.tmpStates.insert(transition.stateIdx)
            }
        }
        swap(&state.currentNdfaStates, &state.tmpStates)
    }

    func findInRange(buffer: UnsafeBufferPointer<UInt8>, bufPos: Int, patternPos: Int) -> Bool {
        let codepointLength = Int(utf8CodepointLengthTable[Int(buffer[bufPos])])

        let patternCodepointLength = Int(utf8CodepointLengthTable[Int(ndfa.pattern[patternPos])])
        if codepointLength != patternCodepointLength { return false }

        let firstPatternCodepointIdx = patternPos
        // 'symbol1Bytes' '-' 'symbol2bytes'
        // len1 +          1 = symbol2StartPos
        var secondPatternCodepointIdx = patternPos + codepointLength + 1
        if ndfa.pattern[secondPatternCodepointIdx] == .backslash {
            secondPatternCodepointIdx += 1
        }

        let upperCompare = compareUtf8Codepoints(buffer: buffer, bufPos: bufPos, patternPos: firstPatternCodepointIdx, codepointLength: codepointLength)
        let lowerCompare = compareUtf8Codepoints(buffer: buffer, bufPos: bufPos, patternPos: secondPatternCodepointIdx, codepointLength: codepointLength)

        // less than upper bound or more than lower bound
        if upperCompare == -1 || lowerCompare == 1 { return false }

        return true
    }

    func findInSet(buffer: UnsafeBufferPointer<UInt8>, bufPos: Int, patternPos: Int) -> Bool {
        let codepointLength = Int(utf8CodepointLengthTable[Int(buffer[bufPos])])
        let patternSize = ndfa.pattern.count
        var patternPos = patternPos
        while patternPos < patternSize {
            var ch = ndfa.pattern[patternPos]
            if ch == .backslash {
                patternPos += 1
                ch = ndfa.pattern[patternPos]
            } else if ch == .closingBracket {
                return false
            }

            let patternCodepointLength = Int(utf8CodepointLengthTable[Int(ch)])

            guard codepointLength == patternCodepointLength else {
                patternPos += patternCodepointLength
                continue
            }

            if 0 == compareUtf8Codepoints(buffer: buffer, bufPos: bufPos, patternPos: patternPos, codepointLength: codepointLength) {
                return true
            }

            patternPos += patternCodepointLength
        }

        return false
    }

    func process(buffer: UnsafeBufferPointer<UInt8>, using state: inout GlobState) {
        var bufSize = buffer.count
        var bufPos = 0

        // skip leading and trailing slashes
        while bufSize > 0, buffer[bufSize - 1] == .slash {
            bufSize -= 1
        }
        while bufPos < bufSize, buffer[bufPos] == .slash {
            bufPos += 1
        }

        while bufPos < bufSize {
            let firstByte = buffer[bufPos]
            let codepointLength = Int(utf8CodepointLengthTable[Int(firstByte)])

            processEpsilonTransitions(in: &state)

            state.tmpStates.removeAll(keepingCapacity: true)
            for stateIdx in state.currentNdfaStates {
                ndfa.states[stateIdx].transitions.forEach { transition in
                    switch transition.type {
                    case .epsilon:
                        // epsilon transitions are skipped when
                        // processing bytes
                        return

                    case .any:
                        break
                    case .anyExceptSlash:
                        if firstByte == .slash { return }
                    case .slash:
                        if firstByte != .slash { return }

                    case .ascii(let tChar):
                        if firstByte != tChar { return }
                    case .notAscii(let tChar):
                        if firstByte == tChar { return }
                    case let .asciiRange(tCh1, tCh2):
                        if firstByte < tCh1 || firstByte > tCh2 { return }
                    case let .notAsciiRange(tCh1, tCh2):
                        if firstByte >= tCh1, firstByte <= tCh2 { return }

                    case .utf8(let idx):
                        if codepointLength < 2 { return }
                        let patternCodepointLength = Int(utf8CodepointLengthTable[Int(ndfa.pattern[idx])])
                        if codepointLength != patternCodepointLength { return }
                        let compareResult = compareUtf8Codepoints(buffer: buffer, bufPos: bufPos, patternPos: Int(idx), codepointLength: codepointLength)
                        if compareResult != 0 { return }

                    case .notUtf8(let idx):
                        if codepointLength < 2 { break }
                        let patternCodepointLength = Int(utf8CodepointLengthTable[Int(ndfa.pattern[idx])])
                        if codepointLength != patternCodepointLength { break }
                        let compareResult = compareUtf8Codepoints(buffer: buffer, bufPos: bufPos, patternPos: Int(idx), codepointLength: codepointLength)
                        if compareResult == 0 { return }

                    case .utf8Range(let idx):
                        let found = findInRange(buffer: buffer, bufPos: bufPos, patternPos: Int(idx))
                        guard found else { return }

                    case .notUtf8Range(let idx):
                        let found = findInRange(buffer: buffer, bufPos: bufPos, patternPos: Int(idx))
                        if found { return }

                    case .set(let patternPos):
                        let result = findInSet(buffer: buffer, bufPos: bufPos, patternPos: Int(patternPos))
                        guard result else { return }
                    case .notSet(let patternPos):
                        let result = findInSet(buffer: buffer, bufPos: bufPos, patternPos: Int(patternPos))
                        if result { return }
                    }

                    state.tmpStates.insert(transition.stateIdx)
                }
            }
            swap(&state.currentNdfaStates, &state.tmpStates)

            bufPos += codepointLength

            if state.currentNdfaStates.isEmpty {
                return
            }
        }

        processEpsilonTransitions(in: &state)
    }

    func checkMatch(in state: inout GlobState) -> (fullMatch: Bool, partialMatch: Bool) {
        var fullMatch = false
        var partialMatch = false
        for stateIdx in state.currentNdfaStates {
            if ndfa.states[stateIdx].isMatch {
                fullMatch = true
            } else {
                partialMatch = true
            }
        }

        return (fullMatch: fullMatch, partialMatch: partialMatch)
    }

    public func match(string: String) -> Bool {
        var string = string
        return string.withUTF8 { buffer in
            var state = GlobState(currentNdfaStates: [0])

            addSlash(to: &state)
            process(buffer: buffer, using: &state)
            addSlash(to: &state)
            processEpsilonTransitions(in: &state)

            let (fullMatch, _) = checkMatch(in: &state)
            return fullMatch
        }
    }
}

extension Glob {
    public init(_ pattern: String) throws {
        self.ndfa = try GlobNDFABuilder.build(globPattern: pattern)
    }

    public static func isGlob(_ string: String) -> Bool {
        var string = string

        return string.withUTF8 { buffer in
            let bufSize = buffer.count
            var i = 0

            while i < bufSize {
                switch buffer[i] {
                case .asterisk, .openingBrace, .closingBrace, .openingBracket, .closingBracket, .questionMark:
                    return true
                default:
                    break
                }

                i += 1
            }

            return false
        }
    }
}
