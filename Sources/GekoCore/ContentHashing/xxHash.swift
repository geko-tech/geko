import Foundation
import xxHash

public final class XXH3 {
    static public func digest64(_ data: Data) -> UInt64 {
        guard data.count > 0 else {
            return digest64([UInt8]())
        }
        return data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            // If the baseAddress of this buffer is nil, the count is zero.
            return XXH3_64bits(pointer.baseAddress!, data.count)
        }
    }
    
    static public func digest64(_ input: [UInt8]) -> UInt64 {
        return XXH3_64bits(input, input.count)
    }
}
