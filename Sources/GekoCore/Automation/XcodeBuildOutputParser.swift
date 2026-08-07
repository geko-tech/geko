import Foundation

public protocol XcodeBuildOutputParsing {
    func parse(line: String) -> XcodeBuildEvent?
}

public final class XcodeBuildOutputParser: XcodeBuildOutputParsing {
    
    private static let targetContextRegex = try! NSRegularExpression(
        pattern: #"\(in target '(.+)' from project '.+'\)$"#,
        options: []
    )
    
    public init() {}
    
    // MARK: - XcodeBuildOutputParsing
    
    public func parse(line: String) -> XcodeBuildEvent? {
        let line = line.trimmingCharacters(in: .whitespaces)
        
        guard let operation = parseOperation(line: line) else {
            return nil
        }
        guard let targetName = parseTargetName(line: line) else {
            return nil
        }
        
        switch operation {
        case .compileC, .compileSwift:
            return .targetCompilationStarted(targetName: targetName)
        case .processInfoPlistFile:
            return .processInfoPlistFile(targetName: targetName)
        case .touch:
            return .targetTouched(targetName: targetName)
        }
    }
    
    // MARK: - Private
    
    private func parseOperation(line: String) -> XcodeBuildOperation? {
        guard let operationName = line.split(maxSplits: 1, whereSeparator: \.isWhitespace).first else {
            return nil
        }
        return XcodeBuildOperation(rawValue: String(operationName))
    }
    
    private func parseTargetName(line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = XcodeBuildOutputParser.targetContextRegex.firstMatch(in: line, range: range) else {
            return nil
        }
        guard let targetRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[targetRange])
    }
}
