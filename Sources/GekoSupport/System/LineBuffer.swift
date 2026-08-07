import Foundation

struct LineBuffer {
    private var data = Data()
    
    mutating func append(_ bytes: [UInt8]) -> [String] {
        data.append(contentsOf: bytes)
        var lines: [String] = []
        
        while let newLineIndex = data.firstIndex(of: 0x0A) {
            let lineData = data[..<newLineIndex]
            data.removeSubrange(...newLineIndex)
            
            lines.append(String(decoding: lineData, as: UTF8.self))
        }
        return lines
    }
    
    mutating func finish() -> String? {
        guard !data.isEmpty else { return nil }
        defer { data.removeAll() }
        
        return String(decoding: data, as: UTF8.self)
    }
}
