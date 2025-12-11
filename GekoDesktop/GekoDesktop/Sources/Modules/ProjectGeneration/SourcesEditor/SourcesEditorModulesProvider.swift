import Foundation

protocol ISourcesEditorModulesProvider: ObservableObject {
    var filteredSelectedModules: [ModuleItem] { get set }
    var filteredAllModules: [ModuleItem] { get set }
    
    var regexText: String { get set }
    var regexes: [String] { get set }

    var selectedModules: [ModuleItem] { get }
    var allModules: [ModuleItem] { get }
    
    var searchText: String { get set }

    var onlyAdded: Bool { get set }
    var fromRegex: Bool { get set }
    var showTests: Bool { get set }
    var showMocks: Bool { get set }
    
    func didSelectModule(_ module: ModuleItem)
    func updateSearch()
    func addRegex()
    func removeRegex(at index: Int)
}

@Observable
final class SourcesEditorModulesProvider: ISourcesEditorModulesProvider {
    var filteredSelectedModules: [ModuleItem]
    var filteredAllModules: [ModuleItem]
    
    var selectedModules: [ModuleItem]
    var allModules: [ModuleItem]
    
    var onlyAdded: Bool = false
    var fromRegex: Bool = false
    var showTests: Bool = false
    var showMocks: Bool = false
    
    var regexText: String = ""
    var regexes: [String]
    
    var searchText: String = "" {
        didSet { updateSearch() }
    }
    
    private let userModules: [String]
    
    init(userModules: [String], userRegex: [String], modules: [String]) {
        self.userModules = userModules
        self.regexes = userRegex
        
        let items = modules.map {
            ModuleItem(from: $0, userModules: userModules, userRegex: userRegex)
        }
        self.selectedModules = items.filter { $0.isSelected }
        self.allModules = items
        
        self.filteredSelectedModules = items.filter { $0.isSelected }.sorted()
        self.filteredAllModules = items.sorted()
    }
    
    func didSelectModule(_ module: ModuleItem) {
        selectedModules = allModules.filter { $0.isSelected }
        updateSearch()
    }
    
    func updateSearch() {
        filteredSelectedModules = filter(selectedModules)
        filteredAllModules = filter(allModules)
    }

    func filter(_ modules: [ModuleItem]) -> [ModuleItem] {
        let addedModules: [ModuleItem]
        if onlyAdded && fromRegex {
            addedModules = modules
                .filter  { $0.isSelected || $0.isInRegex }
        } else {
            addedModules = modules
                .filter { onlyAdded ? $0.isSelected : true }
                .filter { fromRegex ? $0.isInRegex : true }
        }
        
        return addedModules
            .filter { showTests ? $0.isTest : true }
            .filter { showMocks ? $0.isMock : true }
            .filter { searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased()) }
            .sorted()
    }
    
    func addRegex() {
        regexes.append(regexText)
        allModules.forEach { $0.update(with: regexText) }
        updateSearch()
        regexText = ""
    }
    
    func removeRegex(at index: Int) {
        guard index >= 0 && index < regexes.count else { return }
        
        let regexToRemove = regexes[index]
        allModules.forEach { $0.update(removedRegex: regexToRemove) }
        regexes.remove(at: index)
        updateSearch()
    }
}
