import Foundation
import ProjectDescription

extension FileHeaderTemplate {
    public init(fileHeader: String) {
        self = .string(fileHeader)
    }

    public func normalize() throws -> String {
        var fileHeader: String

        switch self {
        case let .file(templatePath):
            fileHeader = try String(contentsOf: templatePath.asURL)
        case let .string(str):
            fileHeader = str
        }

        // As Xcode appends file header directly after `//` it adds to the beginning of template,
        // it is desired to also add leading space if it is not already present,
        // but if header starts with `//` then I know what I am doing and it should be kept intact
        if !fileHeader.hasPrefix("//"), let first = fileHeader.first.map(String.init),
           first.trimmingCharacters(in: .whitespacesAndNewlines) == first
        {
            fileHeader.insert(" ", at: fileHeader.startIndex)
        }

        // Xcode by default adds comment slashes to first line of header template
        if fileHeader.hasPrefix("//") {
            fileHeader.removeFirst(2)
        }

        // Xcode by default adds extra newline at the end, so if it is present, just remove it
        if fileHeader.last == "\n" {
            fileHeader.removeLast()
        }

        return fileHeader
    }
}
