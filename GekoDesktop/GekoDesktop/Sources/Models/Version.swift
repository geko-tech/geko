import Foundation

struct Version: Codable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    
    var string: String {
        "\(major).\(minor).\(patch)"
    }
    
    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    init?(string: String) {
        let numbers = string.split(separator: ".").compactMap { Int($0) }
        guard !numbers.isEmpty else {
            return nil
        }
        self.init(
            major: numbers[0],
            minor: numbers.count > 1 ? numbers[1] : 0,
            patch: numbers.count > 2 ? numbers[2] : 0
        )
    }
}
