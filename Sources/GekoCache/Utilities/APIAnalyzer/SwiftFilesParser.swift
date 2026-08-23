import Foundation
import SwiftParser
import SwiftSyntax
import ProjectDescription
import GekoSupport

private struct ParsedFile {
    let path: AbsolutePath
    let tree: SourceFileSyntax
    let publicTypeNames: Set<String>
    let nonPublicTypeNames: Set<String>
}

final class SwiftFilesParser {
    private let macroNames: Set<String>
    
    init(macroNames: Set<String>) {
        self.macroNames = macroNames
    }
    
    func analyzeModule(sources: [(path: AbsolutePath, content: String)]) -> [FileAnalyzeReport] {
        guard !sources.isEmpty else { return [] }
        let parsedFiles: Atomic<[ParsedFile?]> = Atomic(wrappedValue: Array(repeating: nil, count: sources.count))
        DispatchQueue.concurrentPerform(iterations: sources.count) { index in
            let input = sources[index]
            let tree = Parser.parse(source: input.content)
            let visitor = ModuleTypeVisibilityVisitor()
            visitor.walk(tree)
            parsedFiles.modify { values in
                values[index] = ParsedFile(
                    path: input.path,
                    tree: tree,
                    publicTypeNames: visitor.publicTypesNames,
                    nonPublicTypeNames: visitor.nonPublicTypeNames
                )
            }
        }
        
        let parsedValues = parsedFiles.wrappedValue.compactMap { $0 }
        let publicTypeNames = parsedValues.reduce(into: Set<String>()) { $0.formUnion($1.publicTypeNames) }
        let nonPublicTypeNames = parsedValues.reduce(into: Set<String>()) { $0.formUnion($1.nonPublicTypeNames) }
        let analyzedFiles: Atomic<[FileAnalyzeReport?]> = Atomic(wrappedValue: Array(repeating: nil, count: parsedValues.count))
        
        DispatchQueue.concurrentPerform(iterations: parsedValues.count) { index in
            let item = parsedValues[index]
            let converter = SourceLocationConverter(fileName: item.path.pathString, tree: item.tree)
            let visitor = SwiftFileAPIVisitor(
                path: item.path,
                converter: converter,
                publicTypeNames: publicTypeNames,
                nonPublicTypeNames: nonPublicTypeNames,
                macroNames: macroNames
            )
            let reasons = visitor.reasons
            analyzedFiles.modify { value in
                value[index] = FileAnalyzeReport(
                    path: item.path.pathString,
                    classification: !reasons.isEmpty ? .unsafe : (visitor.hasPublicAPI ? .safe : .noPublicApi),
                    unsafeReasons: reasons,
                    diagnostics: visitor.diagnostics
                )
            }
        }
        return analyzedFiles.wrappedValue.compactMap { $0 }
    }
}
