import Foundation
import GekoSupport

struct XcodeBuildTestCaseParser {

    private static let testCaseStartedRegex = try! NSRegularExpression(
        pattern: #"^Test Case '-\[(.*?) (.*)\]' started.$"#
    )
    private static let testCasePassedRegex = try! NSRegularExpression(
        pattern: #"^\s*Test Case\s'-\[(.*?)\s(.*)\]'\spassed\s\((\d*\.\d{3})\sseconds\)."#
    )
    private static let parallelTestCasePassedRegex = try! NSRegularExpression(
        pattern: #"^Test\s+case\s+'(.*)[\.\/](.*)\(\)'\s+passed\s+on\s+'(.*)'\s+\((\d*\.(.*){3})\s+seconds\)"#
    )
    private static let testCaseFailedRegex = try! NSRegularExpression(
        pattern: #"^\s*Test Case\s'-\[(.*?)\s(.*)\]'\sfailed\s\((\d*\.\d{3})\sseconds\)."#
    )
    private static let parallelTestCaseFailedRegex = try! NSRegularExpression(
        pattern: #"^Test\s+case\s+'(.*)[\./](.*)\(\)'\s+failed\s+on\s+'(.*)'\s+\((\d*\.(.*){3})\s+seconds\)"#
    )
    private static let allTestsCompletedRegex = try! NSRegularExpression(
        pattern: #"xcodebuild.*Testing started completed.$"#
    )

    private struct Matcher {
        let regex: NSRegularExpression
        let makeEvent: (String, String) -> XcodeBuildEvent

        func match(_ line: String) -> XcodeBuildEvent? {
            guard let captures = line.allMatches(with: regex),
                  let suite = captures[safe: 0],
                  let testCase = captures[safe: 1]
            else {
                return nil
            }
            return makeEvent(suite, testCase)
        }
    }

    private static let matchers: [Matcher] = [
        Matcher(regex: testCaseStartedRegex) { .testCaseStarted(suite: $0, testCase: $1) },
        Matcher(regex: testCasePassedRegex) { .testCasePassed(suite: $0, testCase: $1) },
        Matcher(regex: parallelTestCasePassedRegex) { .parallelTestCasePassed(suite: $0, testCase: $1) },
        Matcher(regex: testCaseFailedRegex) { .testCaseFailed(suite: $0, testCase: $1) },
        Matcher(regex: parallelTestCaseFailedRegex) { .parallelTestCaseFailed(suite: $0, testCase: $1) },
    ]

    func parse(line: String) -> XcodeBuildEvent? {
        let line = line.trimmingCharacters(in: .whitespaces)

        for matcher in Self.matchers {
            if let event = matcher.match(line) {
                return event
            }
        }

        if Self.allTestsCompletedRegex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) != nil {
            return .allTestsCompleted
        }

        return nil
    }
}
