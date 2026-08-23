import Foundation
import ProjectDescription
import GekoGraph
import GekoSupport

public protocol IProjectAPIAnalyzer {
    func analyze(graph: Graph) throws -> APIAnalyzeReport
}

enum ProjectApiAnalyzerError: FatalError {
    case readSourceFileError(targetName: String, path: String, error: Error)
    
    var description: String {
        switch self {
        case let .readSourceFileError(targetName, path, error):
            return "Couldn't read swift source file owened by target \(targetName)\nPath:\(path)\nError:\(error)"
        }
    }
    
    var type: ErrorType {
        switch self {
        case .readSourceFileError:
            return .abort
        }
    }
}

public final class ProjectAPIAnalyzer: IProjectAPIAnalyzer {
    private let macroNames: Set<String>
    
    // MARK: - Initialization
    
    public init(macroNames: Set<String> = []) {
        self.macroNames = macroNames
    }
    
    // MARK: - IProjectAPIAnalyzer
    
    public func analyze(graph: Graph) throws -> APIAnalyzeReport {
        let targets: [Target] = Array(graph.targets.values
            .flatMap { $0.values }
            .filter { $0.product == .framework || $0.product == .staticFramework })
        let result: Atomic<[ModuleReport?]> = Atomic(wrappedValue: Array(repeating: nil, count: targets.count))
        let handleError: Atomic<Error?> = Atomic(wrappedValue: nil)
        DispatchQueue.concurrentPerform(iterations: targets.count) { index in
            do {
                let targetAnalyzeReport = try analyze(target: targets[index])
                result.modify { value in
                    value[index] = targetAnalyzeReport
                }
            } catch {
                handleError.modify { value in
                    value = error
                }
            }
        }
        if let handledError = handleError.wrappedValue {
            throw handledError
        }
        
        let analyzedTargets = result.wrappedValue.compactMap { $0 }
        let modulesWithSwiftSources = analyzedTargets.filter { $0.swiftFiles > 0 }.count
        let unsafeModules = analyzedTargets.filter(\.containsUnsafeAPI).count
        let apiFiles = analyzedTargets.reduce(0) { $0 + $1.apiFiles }
        let unsafeApiFiles = analyzedTargets.reduce(0) { $0 + $1.unsafeApiFiles }
        var unsafeReasons = Dictionary(uniqueKeysWithValues: UnsafeApiReason.allCases.map { ($0, 0) })
        for file in analyzedTargets.flatMap(\.files) {
            for reason in file.unsafeReasons { unsafeReasons[reason, default: 0] += 1 }
        }
        let diagnostics = analyzedTargets.flatMap(\.files).flatMap(\.diagnostics)
            .sorted { ($0.file, $0.line, $0.column) < ($1.file, $1.line, $1.column) }
        return APIAnalyzeReport(
            summary: APIAnalyzeSummary(
                modules: analyzedTargets.count,
                modulesWithSwiftSources: modulesWithSwiftSources,
                unsafeModules: unsafeModules,
                unsafeModuleRatio: ratio(unsafeModules, modulesWithSwiftSources),
                apiFiles: apiFiles,
                unsafeApiFiles: unsafeApiFiles,
                unsafeApiRatio: ratio(unsafeApiFiles, apiFiles),
                unsafeReasons: unsafeReasons
            ),
            diagnostics: diagnostics
        )
    }
    
    // MARK: - Private
    
    private func analyze(target: Target) throws -> ModuleReport {
        let swiftPaths = Array(Set(target.sources.flatMap { $0.paths }))
            .filter { $0.extension == "swift" }
            .sorted { $0.pathString < $1.pathString }
        var readedSources: [(path: AbsolutePath, content: String)] = []
        for path in swiftPaths {
            readedSources.append((path, try FileHandler.shared.readTextFile(path)))
        }
        let parser = SwiftFilesParser(macroNames: macroNames)
        let analyzedFiles = parser.analyzeModule(sources: readedSources)
        
        let safeFiles = analyzedFiles.filter({ $0.classification == .safe }).count
        let unsafeFiles = analyzedFiles.filter({ $0.classification == .unsafe }).count
        let apiFiles = safeFiles + unsafeFiles
        
        return ModuleReport(
            name: target.name,
            swiftFiles: readedSources.count,
            apiFiles: apiFiles,
            unsafeApiFiles: unsafeFiles,
            unsafeApiRatio: ratio(unsafeFiles, apiFiles),
            containsUnsafeAPI: unsafeFiles > 0,
            files: analyzedFiles
        )
    }
    
    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }
}

public enum APIAnalyzeReportRenderer {
    public static func text(_ report: APIAnalyzeReport) -> String {
        let summary = report.summary
        func percent(_ ratio: Double) -> String { String(format: "%.1f%%", ratio * 100) }

        var lines = [
            "Public API analysis", "",
            "Modules: \(summary.modules)",
            "Modules with Swift sources: \(summary.modulesWithSwiftSources)",
            "Modules with unsafe API: \(summary.unsafeModules)",
            "Unsafe module ratio: \(percent(summary.unsafeModuleRatio))",
            "Unsafe API ratio: \(percent(summary.unsafeApiRatio))",
            "Unsafe reasons:"
        ]
        for reason in UnsafeApiReason.allCases {
            lines.append("  \(reason.rawValue) \(summary.unsafeReasons[reason, default: 0])")
        }
        return lines.joined(separator: "\n")
    }
}
