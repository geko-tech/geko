import Foundation

public struct CompleteMultipartUpload: Sendable {

    public struct Part: Sendable {
        public let eTag: String?
        public let partNumber: Int?

        public init(
            eTag: String? = nil,
            partNumber: Int? = nil
        ) {
            self.eTag = eTag
            self.partNumber = partNumber
        }
    }

    public let parts: [Part]
    
    public init(
        parts: [Part] = []
    ) {
        self.parts = parts
    }
}
