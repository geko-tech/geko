import SwiftUI

@MainActor
class ShortcutsAppState: ObservableObject {
    @Published var isLoaded: Bool = false
    @Published var shortcuts: [GitShortcut] = []
    @Published var dependencyAssembly = DependenciesAssembly()
    
    init() {
        Task { await loadData() }
    }
    
    func loadData() async {
        shortcuts = (try? await dependencyAssembly.shortcutsProvider.loadShortcuts()) ?? []
        isLoaded = true
    }
}
