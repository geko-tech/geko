import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

public protocol HeadersContentHashing {
    func hash(headers: HeadersList) throws -> (String, [String: String])
}

/// `HeadersContentHashing`
/// is responsible for computing a hash that uniquely identifies a list of headers
public final class HeadersContentHasher: HeadersContentHashing {
    private let contentHasher: ContentHashing
    private let relativePathConverter: RelativePathConverting

    // MARK: - Init

    public init(
        contentHasher: ContentHashing,
        relativePathConverter: RelativePathConverting = RelativePathConverter()
    ) {
        self.contentHasher = contentHasher
        self.relativePathConverter = relativePathConverter
    }

    // MARK: - HeadersContentHashing

    public func hash(headers: HeadersList) throws -> (String, [String: String]) {
        var headersHashInfo: [String: String] = [:]
        var allHeaders: [FilePath] = []

        headers.list.forEach {
            allHeaders += $0.public?.files ?? []
            allHeaders += $0.private?.files ?? []
            allHeaders += $0.project?.files ?? []
        }

        for header in allHeaders {
            headersHashInfo[relativePathConverter.convert(header).pathString] = try contentHasher.hash(path: header)
        }
        return (try contentHasher.hash(headersHashInfo.values.sorted()), headersHashInfo)
    }
}
