import Crypto
import Foundation

enum SHA256Digest {
    enum InputStreamError: Error {
        case createFailed(URL)
        case readFailed
    }

    static func file(at url: URL) throws -> Data {
        var digest = Crypto.SHA256()
        try update(url: url, digest: &digest)
        let result = digest.finalize()
        return Data(result)
    }

    private static func update(url: URL, digest: inout Crypto.SHA256) throws {
        guard let inputStream = InputStream(url: url) else {
            throw InputStreamError.createFailed(url)
        }
        return try update(inputStream: inputStream, digest: &digest)
    }

    private static func update(inputStream: InputStream, digest: inout Crypto.SHA256) throws {
        inputStream.open()
        defer { inputStream.close() }

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                // Stream error occured
                throw (inputStream.streamError ?? InputStreamError.readFailed)
            } else if bytesRead == 0 {
                // EOF
                break
            }
            update(bytes: buffer, length: bytesRead, digest: &digest)
        }
    }

    private static func update(bytes: UnsafeRawPointer?, length: Int, digest: inout Crypto.SHA256) {
        digest.update(bufferPointer: UnsafeRawBufferPointer(start: bytes, count: length))
    }
}
