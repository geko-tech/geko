import Foundation
import ProjectDescription
import GekoGraph
import GekoSupport

public protocol IProjectAPIAnalyzer {
    func analyze(graph: Graph) throws
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
    
    private let macroNames: Set<String> = ["TCodable"]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - IProjectAPIAnalyzer
    
    public func analyze(graph: Graph) throws {
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
    }
    
    // MARK: - Private
    
    private func analyze(target: Target) throws -> ModuleReport {
        let swiftPaths = target.sources.flatMap { $0.paths }.filter { $0.extension == "swift" }
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
