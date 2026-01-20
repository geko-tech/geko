import Foundation
import GekoGraph
import GekoSupportTesting
import ProjectDescription

extension FileHeaderTemplate {
    public static func test(fileHeader: String = "Header template") -> FileHeaderTemplate {
        FileHeaderTemplate(fileHeader: fileHeader)
    }
}
