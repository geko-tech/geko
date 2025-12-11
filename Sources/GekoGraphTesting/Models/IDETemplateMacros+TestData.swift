import Foundation
import GekoGraph
import GekoSupportTesting

extension IDETemplateMacros {
    public static func test(fileHeader: String = "Header template") -> IDETemplateMacros {
        IDETemplateMacros(fileHeader: fileHeader)
    }
}
