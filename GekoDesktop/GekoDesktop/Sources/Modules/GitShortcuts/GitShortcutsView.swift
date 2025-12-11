import SwiftUI

struct GitShortcutsView<T: IGitShortcutsViewStateOutput>: View {
    
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    var body: some View {
        ScrollView {
            switch viewState.state {
            case .empty:
                if viewState.isImportLoading {
                    loadingView
                }
                emptyView
            case let .cached(shortcuts):
                loadingView
                shortcutsView(shortcuts: shortcuts)
            case let .loaded(shortcuts):
                if shortcuts.isEmpty {
                    if viewState.isImportLoading {
                        loadingView
                    }
                    emptyView
                } else {
                    if viewState.isImportLoading {
                        loadingView
                    }
                    shortcutsView(shortcuts: shortcuts)
                }
            case let .error(description):
                HStack {
                    Text(description)
                    Image.danger.foregroundStyle(.red)
                }
            }
            
        }
        .disabled(viewState.isViewDisabled)
        .onAppear(perform: {
            viewState.onAppear()
        }).sheet(isPresented: $viewState.showErrorDialog) {
            errorDialog
        }.sheet(isPresented: $viewState.showInputDialog) {
            inputDialog
        }.sheet(isPresented: $viewState.showShareDialog) {
            FileShareDialog(
                fileName: viewState.shareFileName,
                description: "Ask your teammate to open \"Git Shortcuts\" and choose \"Import\"",
                url: viewState.shareFileUrl,
                cancel: {
                    viewState.cancelSharing()
                }
            )
        }.sheet(isPresented: $viewState.showAddDialog) {
            AnyView(dependencies.shortcutEditorAssembly.build(editingShortcut: viewState.editingShortcut, addPayload: viewState.addPayload) {
                viewState.editingShortcut = nil
                viewState.showAddDialog = false
            })
        }
    }

    var errorDialog: some View {
        VStack {
            Text(viewState.error ?? "Unknown error").font(.cellTitle).padding([.leading, .top])
            Button(action: {
                viewState.dismissErrorDialog()
            }, label: {
                Text("Ok")
            })
        }
        .padding()
    }
    
    var inputDialog: some View {
        VStack {
            HStack {
                Text("Input").font(.cellTitle)
                Spacer()
            }
            TextField("Enter command input", text: $viewState.input).padding(.bottom)
            HStack {
                Spacer()
                Button(action: {
                    viewState.dismissInputDialog(false)
                }, label: {
                    Text("Cancel")
                })
                Button(action: {
                    viewState.dismissInputDialog(true)
                }, label: {
                    Text("Ok")
                })
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
    
    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.small).padding(.bottom)
        }
    }
    
    var emptyView: some View {
        VStack {
            Spacer()
            Text("There's nothing here yet.")
                .padding([.top, .bottom])
                .foregroundStyle(viewState.isViewDisabled ? .gray : .primary)
            HStack {
                Spacer()
                importButton
                addButton.padding(.trailing, 8)
                Spacer()
            }
            Spacer()
        }.padding(.top)
    }
    
    var addButton: some View {
        Button(action: {
            viewState.addShortcut()
        }, label: {
            Text("Add shortcut")
        })
        .buttonStyle(.borderedProminent)
    }
    
    var importButton: some View {
        Button(action: {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.json]
            if panel.runModal() == .OK {
                if let url = panel.url {
                    viewState.importConfiguration(url)
                } else {
                    viewState.showErrorDialog = true
                }
            }
        }, label: {
            Text("Import")
        })
        .buttonStyle(.bordered)
    }
    
    var shareButton: some View {
        HStack {
            if viewState.isShareLoading {
                ProgressView().controlSize(.small)
            } else {
                Button(action: {
                    viewState.shareConfiguration()
                }, label: {
                    Text("Share")
                })
                .buttonStyle(.bordered)
            }
        }
    }
    
    func shortcutsView(shortcuts: [GitShortcut]) -> some View {
        VStack {
            ForEach(shortcuts, id: \.self) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.cellTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(viewState.isViewDisabled ? .gray : .primary)
                        if !item.description.isEmpty {
                            Text(item.description).font(.footnote).foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    Image.delete
                        .resizable()
                        .foregroundStyle(viewState.isViewDisabled ? .gray : .red)
                        .frame(width: 14, height: 16)
                        .onTapGesture {
                            viewState.askToRemoveShortcut(item)
                        }
                        .padding([.trailing], 8)
                    Button(action: {
                        viewState.editShortcut(item)
                    }, label: {
                        Text("Edit")
                    }).padding([.trailing], 8)
                    
                    if viewState.isRunLoading && viewState.runningShortcut == item {
                        ProgressView().controlSize(.small)
                    } else {
                        Image.play
                            .resizable()
                            .foregroundStyle(viewState.isViewDisabled ? .gray : .blue)
                            .frame(width: 14, height: 16)
                            .onTapGesture {
                                viewState.runShortcut(item)
                            }
                    }
                }
                .padding()
                .background(.cellBackground)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.cellBorder, lineWidth: 1)
                )
                .confirmationDialog(
                    "Are you sure you want to delete shortcut?",
                    isPresented: $viewState.showRemoveDialog
                ) {
                    Button("Yes") {
                        withAnimation {
                            viewState.removeShortcut()
                        }
                    }.keyboardShortcut(.defaultAction)

                    Button("No", role: .cancel) {
                        viewState.cancelRemove()
                    }
                }
            }
            .padding([.leading, .trailing])
            
            HStack {
                Spacer()
                shareButton
                importButton
                addButton
            }.padding()
        }.padding(.top)
    }
}
