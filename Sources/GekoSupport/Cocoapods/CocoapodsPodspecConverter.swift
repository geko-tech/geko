import Foundation

public enum CocoapodsPodspecConverterError: FatalError, Equatable {
    public var type: ErrorType { .abort }

    case lessJsonsThanPodspecs(specPath: String, json: String)
    case moreJsonsThanPodspecs
    case spaceInPodspecPath(specPath: String)

    static let ipcSpecScript = """
        ```
        #!/bin/bash
        podspecs=( $(find ./LocalPods -name '*.podspec') )
        commands=''

        for i in ${podspecs[@]}
        do
            commands+="spec ${i}"
            commands+=$'\\n'
        done

        pod ipc repl <<< "${commands%?}"
        ```
        """

    public var description: String {
        switch self {
        case let .lessJsonsThanPodspecs(specPath, json):
            return """
                Could not parse podspecs because the number of json objects produced by command `pod ipc repl` did not match the number of podspec files.
                Possibly corrupted json produced by podspec:
                \(json)
                ...

                Possibly invalid podspec: \(specPath)

                Some of the reasons an error occured
                - There's an error in your podspec file
                - One of your podspec files prints output to stdout
                - One of your podspec files does not contain Pod::Spec

                You can review json yourself by using command `pod ipc spec \(specPath)`.
                Output of that command must be a valid json.

                Or, if you want to review every podspec, you can use following script to quickly transform them to a json:
                \(CocoapodsPodspecConverterError.ipcSpecScript)
                """
        case .moreJsonsThanPodspecs:
            return """
                Found more json objects than podspec files while executing command `pod ipc repl`.
                This can only be possible if one of your podspec files outputs json to stdout.
                You need to find a podspec that does outputs json.
                You can do that by saving following command to a file and executing it:
                \(CocoapodsPodspecConverterError.ipcSpecScript)
                """
        case let .spaceInPodspecPath(specPath):
            return "Cannot convert spec at path '\(specPath)', because path contains a whitespace character. Spaces in paths are not supported by cocoapods repl."
        }
    }
}

public protocol CocoapodsPodspecConverting {
    func convert(
        paths: [String],
        shellCommand: [String]
    ) throws -> [(podspecPath: String, podspecData: Data)]
}

public final class CocoapodsPodspecConverter: CocoapodsPodspecConverting {

    private let system: Systeming

    public init(system: Systeming = System.shared) {
        self.system = system
    }

    public func convert(
        paths: [String],
        shellCommand: [String]
    ) throws -> [(podspecPath: String, podspecData: Data)] {

        if let pathWithWhitespace = paths.first(where: { $0.contains(" ") }) {
            throw CocoapodsPodspecConverterError
                .spaceInPodspecPath(specPath: pathWithWhitespace)
        }

        let (command, input) = buildPodspecCommand(paths: paths, baseShellCommand: shellCommand)
        var commandOutput = try system
            .capture(command, withInput: input)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip firstline of repl command result. First line contains techical info like version and name of util.
        commandOutput.removeFirstLine()
        // Repl command returns single string with consecutive json objects for all specs, so we need to
        // convert it to a normal json for easier parsing
        let (jsons, remainder) = commandOutput.splitJsons()

        guard jsons.count == paths.count else {
            if jsons.count < paths.count {
                // some of the podspecs spit out '}' character to the stdout

                let possiblyInvalidPodspec = paths[jsons.count]
                let remainderLines = remainder.split(separator: "\n")
                let invalidJsonChunk = remainderLines.prefix(upTo: min(50, remainderLines.count - 1))
                    .joined(separator: "\n")

                throw CocoapodsPodspecConverterError.lessJsonsThanPodspecs(
                    specPath: possiblyInvalidPodspec,
                    json: invalidJsonChunk
                )
            } else {
                // some of the podspecs spit out json to the stdout
                throw CocoapodsPodspecConverterError.moreJsonsThanPodspecs
            }
        }

        var podspecTuples: [(String, Data)] = []
        for (path, json) in zip(paths, jsons) {
            podspecTuples.append((path, json.data(using: .utf8)!))
        }

        return podspecTuples
    }

    private func buildPodspecCommand(
        paths: [String],
        baseShellCommand: [String]
    ) -> (command: [String], input: String) {
        let command: [String] = baseShellCommand + ["ipc", "repl"]
        let input = "\(paths.map { "spec \($0)" }.joined(separator: "\n"))"
        return (command, input)
    }
}

extension String {
    mutating func removeFirstLine() {
        guard let range = range(of: "\n") else { return }
        removeSubrange(..<range.upperBound)
    }

    mutating func replace(with pattern: String, replacement: String) throws {
        let regex = try NSRegularExpression(pattern: pattern)
        self = regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: NSMakeRange(0, count),
            withTemplate: replacement
        )
        self = regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: NSMakeRange(0, count),
            withTemplate: replacement
        )
    }

    public func splitJsons() -> (jsons: [Substring], remainder: Substring) {
        var result: [Substring] = []

        var index = self.startIndex
        var currentJsonStart = index
        var currentJsonDepth = 0
        var lastCorrectJsonPosition = index

        func remainder() -> Substring {
            guard lastCorrectJsonPosition != endIndex else { return .init() }
            let nextIndex = self.index(after: lastCorrectJsonPosition)
            guard nextIndex != endIndex else { return .init() }

            return self[nextIndex...self.index(before: endIndex)]
        }

        while index != self.endIndex {
            switch self[index] {
            case "{":
                currentJsonDepth += 1

                if currentJsonDepth == 1 {
                    currentJsonStart = index
                }

            case "}":
                currentJsonDepth -= 1

                if currentJsonDepth == 0 {
                    result.append(self[currentJsonStart...index])
                    lastCorrectJsonPosition = index
                } else if currentJsonDepth < 0 {
                    return (result, remainder())
                }

                // skip strings
            case "\"":
                guard currentJsonDepth > 0 else { break }

                index = self.index(after: index)
                while index != self.endIndex {
                    // skip escaped quotes
                    if self[index] == "\\" { index = self.index(index, offsetBy: 2) }

                    if self[index] == "\"" {
                        break
                    }

                    index = self.index(after: index)
                }

            default:
                break
            }

            if index == self.endIndex {
                break
            }

            index = self.index(after: index)
        }

        return (result, remainder())
    }
}
