import Foundation
import PathKit
import struct ProjectDescription.AbsolutePath

extension AbsolutePath {
    var path: Path {
        Path(pathString)
    }
}

extension AbsolutePath {
    var optimizedComponents: some Sequence<(String, Bool)> {
        PathSplitSequence(pathString)
    }

    /// Return last path component if it is not the only component
    /// Shortly, this code is optimized version of
    /// ```
    /// let components = relativePath.components
    /// components.count != 1 ? components.last! : nil
    /// ```
    var lastPathComponentIfNotSingle: String? {
        var pathString = pathString
        return pathString.withUTF8 { buffer in
            let count = buffer.count
            let slash: UInt8 = 47

            guard count > 0 else { return nil }

            var end = count

            // Remove trailing slashes
            while end > 0 && buffer[end - 1] == slash {
                end -= 1
            }

            // If path was only "/" or "////" - return nil
            if end == 0 {
                return nil
            }

            // Find start of last component
            var start = end
            while start > 0 && buffer[start - 1] != slash {
                start -= 1
            }

            // Find if there is another component before it
            var i = start

            // Skip slashes before last component
            while i > 0 && buffer[i - 1] == slash {
                i -= 1
            }

            // root folder is treated as a separate component
            let hasPreviousComponent = i > 0 || buffer[0] == slash

            guard hasPreviousComponent else {
                return nil
            }

            let length = end - start

            // Create String with no UTF‑8 validation
            return String(unsafeUninitializedCapacity: length) { dst in
                dst.baseAddress!.initialize(
                    from: buffer.baseAddress!.advanced(by: start),
                    count: length
                )
                return length
            }
        }
    }
}

private struct PathSplitSequence: Sequence, IteratorProtocol {
    private var string: String
    private let separator: UInt8 = 47 // "/"
    private var offset: Int = 0
    private var emittedLeadingSlash = false

    init(_ string: String) {
        self.string = string
    }

    mutating func next() -> (String, Bool)? {
        return string.withUTF8 { buffer -> (String, Bool)? in
            let count = buffer.count

            // Special-case leading "/"
            if !emittedLeadingSlash,
               offset == 0,
               count > 0,
               buffer[0] == separator {

                emittedLeadingSlash = true
                offset = 1

                let isLast = !hasMoreNonSeparator(buffer, offset: offset, separator: separator)
                return ("/", isLast)
            }

            // Skip separators
            while offset < count && buffer[offset] == separator {
                offset += 1
            }

            guard offset < count else {
                return nil
            }

            let start = offset

            // Scan component
            while offset < count && buffer[offset] != separator {
                offset += 1
            }

            let length = offset - start
            let substring = String(unsafeUninitializedCapacity: length) { dst in
                guard let srcBase = buffer.baseAddress,
                      let dstBase = dst.baseAddress else {
                    return 0
                }

                dstBase.initialize(from: srcBase.advanced(by: start), count: length)
                return length
            }
            let isLast = !hasMoreNonSeparator(buffer, offset: offset, separator: separator)

            return (substring, isLast)
        }
    }
}

private func hasMoreNonSeparator(_ buffer: UnsafeBufferPointer<UInt8>, offset: Int, separator: UInt8) -> Bool {
    var i = offset
    while i < buffer.count {
        if buffer[i] != separator {
            return true
        }
        i += 1
    }
    return false
}
