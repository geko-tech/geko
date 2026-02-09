import SwiftUI

@main
struct GekoDesktopApp: App {
    
    // MARK: - Attributes
    @StateObject private var shortcutsAppState = ShortcutsAppState()
    
    private var dependencyAssembly: DependenciesAssembly {
        shortcutsAppState.dependencyAssembly
    }
    
    // MARK: - UI
    
    var body: some Scene {
        WindowGroup {
            AnyView(dependencyAssembly.mainViewAssembly
                .build())
                .environment(dependencyAssembly)
                .modify { content in
                    if #available(macOS 26, *) {
                        content.frame(width: 1500, height: 700)
                    } else {
                        content.frame(minWidth: 1400, minHeight: 700)
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands(content: { CommandGroup(after: .appInfo) {
            if shortcutsAppState.isLoaded {
                ForEach(shortcutsAppState.shortcuts.filter { $0.keyboardKey != nil }, id: \.self) { shortcut in
                    if
                        let keyboardKey = shortcut.keyboardKey,
                            !keyboardKey.key.isEmpty,
                            !keyboardKey.eventModifiers.isEmpty
                    {
                        Button("Run Regex") {
                            dependencyAssembly.applicationStateHolder.changeSelectedSideBar(
                                .gitShortcuts,
                                payload: [Constants.runShortcutPayload: shortcut.id]
                            )
                        }
                        .keyboardShortcut(
                            KeyEquivalent(Character(keyboardKey.key)),
                            modifiers: keyboardKey.eventModifiers
                        )
                    } else { /* Stub */ }
                }
            }
            else {
                ProgressView().task { await shortcutsAppState.loadData() }
            }
        }})
        .commands(content: {
            CommandGroup(replacing: .newItem) { }
        })
    }
}
