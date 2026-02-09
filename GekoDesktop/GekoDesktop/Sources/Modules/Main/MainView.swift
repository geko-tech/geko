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
            .modify { content in
                if #available(macOS 26, *) {
                    content.navigationSplitViewColumnWidth(250)
                } else {
                    content.frame(minWidth: 200)
                }
            }
        } detail: {
            VSplitView {
                container
                if viewState.showTerminal {
                    AnyView(terminalView)
                }   
            }
            .modify { content in
                if #available(macOS 26, *) {
                    content.navigationSplitViewColumnWidth(988) // 1500 global width - 500 toolbars, - 12 padding
                }
            }
        }
        .inspector(isPresented: $viewState.isInspectorPresented) {
            AnyView(dependencies.workspaceInspectorAssembly
                .build())
            .modify { content in
                if #available(macOS 26, *) {
                    content.frame(width: 250)
                }
            }
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
                    if #available(macOS 26, *) {
                        EmptyView()
                    } else {
                        AnyView(dependencies.toolbarAssembly.buildIfNeeded())
                    }
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
                                .modify { content in
                                    if #available(macOS 26, *) {
                                        content.padding(.leading)
                                    }
                                }
                            ProgressView().foregroundStyle(.blue).controlSize(.small)
                        }
                    case .error(let info):
                        HStack {
                            Text(info)
                                .modify { content in
                                    if #available(macOS 26, *) {
                                        content.padding(.leading)
                                    }
                                }
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
        .modify { content in
            if #available(macOS 26, *) {
                content.background(.containerBackground)
            } else {
                content
                    .background(.containerBackground)
                    .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
