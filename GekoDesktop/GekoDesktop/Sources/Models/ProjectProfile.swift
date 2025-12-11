import Foundation

struct ProjectProfile: Identifiable {
    let name: String
    let options: [String: String]
    
    var id: String { name }
}
