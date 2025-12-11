import Foundation

struct Delete: Sendable {
    let objects: [Object]

    struct Object: Sendable {
        let key: String
    }
}

