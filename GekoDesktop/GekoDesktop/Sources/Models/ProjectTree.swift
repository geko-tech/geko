import Foundation

class ProjectTree: Identifiable, Comparable {

    enum NodeType: Hashable {
        case project
        case target(Product)
    }

    var name: String
    var type: NodeType
    var children: [ProjectTree]?
    var isLocal: Bool
    var isCached: Bool
    weak var parent: ProjectTree?

    var childrenCount: Int {
        if let children = children, children.contains(where: { $0.name == "Internal"}) {
            return children.compactMap { $0.children?.count }.reduce(0, +)
        } else {
            return children?.count ?? 0
        }
    }
    
    var id: String {
        name
    }
    
    init(name: String,
         type: NodeType,
         children: [ProjectTree]? = nil,
         isLocal: Bool, isCached: Bool,
         parent: ProjectTree? = nil) {
        self.name = name
        self.type = type
        self.children = children
        self.isLocal = isLocal
        self.isCached = isCached
        self.parent = parent
    }
    
    func removeCached() {
        children?.forEach { $0.removeCached() }
        let modifiedChildren = children?.filter { !$0.isCached } ?? []
        children = modifiedChildren.isEmpty ? nil : modifiedChildren
    }
    
    func removeCached(_ focusedModules: [String]) {
        /// Return if this leaf has no child
        guard let children = children, !children.isEmpty else {
            return
        }
        /// check that these are not "intermediate" leafs
        let childrenNames = children.map { $0.name }
        if !childrenNames.contains("Internal") && !childrenNames.contains("External") {
            /// remove leaf if it is not exist in focusedModules
            let modifiedChildren = children.filter { focusedModules.contains($0.name) }
            self.children = modifiedChildren 
        }
        
        self.children?.forEach { $0.removeCached(focusedModules) }
    }
    
    func sorted() {
        children = children?.sorted()
        children?.forEach { $0.sorted() }
    }
    
    func splited() {
        self.children?.forEach { $0.splited() }
        guard let children = children, !children.isEmpty else {
            return
        }
        let local = children.filter { $0.isLocal }
        let remote = children.filter { !$0.isLocal }
        guard !local.isEmpty && !remote.isEmpty else {
            return
        }
        let localTree = ProjectTree(name: "Internal", type: type, children: local, isLocal: true, isCached: false, parent: parent)
        let remoteTree = ProjectTree(name: "External", type: type, children: remote, isLocal: false, isCached: isCached, parent: parent)
        self.children = [localTree, remoteTree]
    }

    // MARK: - Comparable & Equatable
    
    static func < (lhs: ProjectTree, rhs: ProjectTree) -> Bool {
        if lhs.isLocal && rhs.isLocal {
            return lhs.name < rhs.name
        } else if lhs.isLocal && !rhs.isLocal {
            return true
        } else if !lhs.isLocal && rhs.isLocal {
            return false
        } else {
            return lhs.name < rhs.name
        }
    }
    
    static func == (lhs: ProjectTree, rhs: ProjectTree) -> Bool {
        switch (lhs.type, rhs.type) {
        case (.project, .project):
            return lhs.name == rhs.name
            && lhs.parent?.name == rhs.parent?.name
        case (.target(let firstTargetType), .target(let secondTargetType)):
            return lhs.name == rhs.name
            && lhs.parent?.name == rhs.parent?.name
            && firstTargetType == secondTargetType
        default:
            return lhs.name == rhs.name
            && lhs.parent?.name == rhs.parent?.name && lhs.childrenCount == rhs.childrenCount
        }
    }
}

extension ProjectTree: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(children)
        hasher.combine(isLocal)
        hasher.combine(isCached)
    }
}
