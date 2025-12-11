import SwiftUI

struct MainView<T: IMainViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI
    
    var body: some View {
        NavigationSplitView() {
            AnyView(dependencies.sideBarAssembly
                .build())
                .frame(minWidth: 200)
        } detail: {
            VSplitView {
                container
                if viewState.showTerminal {
                    AnyView(terminalView)
                }
            }
        }
        .inspector(isPresented: $viewState.isInspectorPresented) {
            AnyView(dependencies.workspaceInspectorAssembly
                .build())
        }
        .errorAlert(error: $viewState.alertError)
        .alert($viewState.appOutdatedError.wrappedValue ?? "", isPresented: .constant($viewState.appOutdatedError.wrappedValue != nil)) { 
            Button("Update app") {
                viewState.updateApp()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack {
                    AnyView(dependencies.toolbarAssembly.buildIfNeeded())
                }
            }
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    switch viewState.runningState {
                    case .notExecuting:
                        EmptyView()
                    case .running(let info):
                        HStack(spacing: 8) {
                            Text(info)
                            ProgressView().foregroundStyle(.blue).controlSize(.small)
                        }
                    case .error(let info):
                        HStack {
                            Text(info)
                            Image.danger.foregroundStyle(.red)
                        }
                    }
                    Button {
                        viewState.reloadProject()
                    } label: {
                        Image.refresh
                    }
                    Button {
                        viewState.toggleTerminal()
                    } label: { 
                        Image.terminal
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbarBackground(.windowBackground)
        .onAppear {
            viewState.onAppear()
        }
    }
    
    var container: some View {
        Group { 
            switch viewState.sideBarSelectedCommand {
            case .welcome:
                AnyView(dependencies.welcomeAssembly
                    .build())
            case .config:
                AnyView(dependencies.gekoConfigAssembly
                    .build())
            case .projectGeneration:
                AnyView(dependencies.projectGeneration1Assembly
                    .build())
            case .gitShortcuts:
                AnyView(dependencies.gitShortcutsAssembly
                    .build(viewState.sideBarPayload))
            case .logs:
                AnyView(dependencies.logsAssebly
                    .build())
            case .settings:
                AnyView(dependencies.gekoDesktopSettingsAssembly
                    .build())
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(.containerBackground)
        .layoutPriority(1)
    }
    
    var terminalView: any View {
        dependencies.projectTerminalAssembly
            .build()
            .padding(4)
            .frame(height: 300)
            .background(.terminalBackground)
    }
}

// MARK: - Alert

extension View {
    func errorAlert(error: Binding<LocalizedAlertError?>) -> some View {
        return alert(isPresented: .constant(error.wrappedValue != nil), error: error.wrappedValue) { _ in
            Button(error.wrappedValue?.actionButtonTitle ?? "") {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.additionalInfo)
        }
    }
}
