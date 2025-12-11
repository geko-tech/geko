import Foundation

class ModuleItem: Identifiable, Comparable {
    
    let name: String
    let isMock: Bool
    let isTest: Bool
    var isSelected: Bool
    var includedInRegexes: [String]
    
    init(from target: String, userModules: [String], userRegex: [String]) {
        isSelected = userModules.contains(target)
        includedInRegexes = userRegex.filter { regex in
            target.range(of: regex, options: .regularExpression) != nil
        }
        self.name = target
        self.isMock = target.hasSuffix("Mock")
        self.isTest = target.hasSuffix("Tests")
    }
    
    // MARK: - Identifiable

    var id: String {
        name
    }
    
    var isInRegex: Bool {
        !includedInRegexes.isEmpty
    }
    
    func update(with regex: String) {
        if name.range(of: regex, options: .regularExpression) != nil {
            includedInRegexes.append(regex)
        }
    }
    
    func update(removedRegex regex: String) {
        includedInRegexes.removeAll { $0 == regex }
    }
        
    // MARK: - Comparable

    static func == (lhs: ModuleItem, rhs: ModuleItem) -> Bool {
        lhs.name == rhs.name
    }
    
    static func < (lhs: ModuleItem, rhs: ModuleItem) -> Bool {
        lhs.name < rhs.name
    }
}
