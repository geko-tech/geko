import SwiftUI

struct ShortcutEditorView<T: IShortcutEditorViewOutput>: View {
    
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @Environment(\.controlActiveState) var controlActiveState
    @StateObject var viewState: T
    
    var body: some View {
        if viewState.isLoading {
            loadingView
            .frame(minWidth: 500, minHeight: 600, maxHeight: 800)
            .onAppear(perform: {
                viewState.onAppear()
            })
        } else {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Text("Shortcut Editor").font(.cellTitle).padding([.top])
                    Spacer()
                }
                nameBar
                descriptionBar
                Text("Commands Order").font(.cellTitle).padding([.leading, .top])
                commandsView
                commandChooseView
                keyCatcherView
                bottomView
            }
            .frame(minWidth: 500, minHeight: 600, maxHeight: 800)
            .onChange(of: controlActiveState) { oldState, newState in
                if oldState == .inactive && newState == .key {
                    viewState.onAppear()
                }
            }.sheet(isPresented: $viewState.showCommandParameters) {
                addExtraDialog
            }
        }
    }
    
    var nameBar: some View {
        HStack {
            TextField("Name", text: $viewState.shortcut.name).cornerRadius(6)
        }.padding([.leading, .trailing])
    }
    
    var descriptionBar: some View {
        HStack {
            TextField("Description", text: $viewState.shortcut.description).cornerRadius(6)
        }.padding([.leading, .trailing])
    }
    
    var addExtraDialog: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Command settings").font(.dialogTitle)
                Spacer()
            }.padding(.bottom)
            Text("Custom flags").font(.dialogSmallTitle)
            TextField("Enter flags if needed", text: $viewState.editedCommand.options).padding(.bottom, 4)
            Toggle(isOn: $viewState.editedCommand.hasInput, label: {
                Text("Use command input")
            })
            Text("The command will ask for input when running").foregroundStyle(.secondary).font(.itemTitle).padding(.top, 4)
            
            HStack {
                Spacer()
                Button(action: {
                    viewState.dismissCommandParametersDialog(false)
                }, label: {
                    Text("Cancel")
                })
                Button(action: {
                    viewState.dismissCommandParametersDialog(true)
                }, label: {
                    Text("Ok")
                })
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    var commandsView: some View {
        List(viewState.commands.indexed(), id: \.1.self, selection: $viewState.selectedCommand) { index, item in
            HStack {
                Image.edit
                    .resizable()
                    .frame(width: 14, height: 16)
                    .onTapGesture {
                        viewState.editCommand(item)
                    }
                    .padding([.trailing], 8)
                Image.delete
                    .resizable()
                    .frame(width: 14, height: 16)
                    .foregroundStyle(.red)
                    .onTapGesture {
                        viewState.removeCommand(item)
                    }
                    .padding([.trailing], 8)
                HStack {
                    Text(item.commandType.commandText).font(.itemTitle).tag(item)
                    
                    if !item.options.isEmpty {
                        Text(item.options).font(.itemTitle)
                            .foregroundStyle(item == viewState.selectedCommand ? .white : .secondary)
                    }
                    if item.hasInput {
                        Text("uses command input")
                            .font(.itemTitle)
                            .foregroundStyle(item == viewState.selectedCommand ? .white : .secondary)
                    }
                    Spacer()
                }.padding([.trailing])
                Spacer()
                if index > 0 {
                    Image.upArrow
                        .resizable()
                        .frame(width: 12, height: 8)
                        .onTapGesture {
                            viewState.moveCommandUp(item)
                        }
                        .padding([.trailing], 8)
                }
                if index < viewState.commands.count - 1 {
                    Image.downArrow
                        .resizable()
                        .frame(width: 12, height: 8)
                        .onTapGesture {
                            viewState.moveCommandDown(item)
                        }
                        .padding([.trailing], 8)
                }
            }.frame(height: 24)
        }
        .cornerRadius(8)
        .padding([.leading, .trailing])
    }
    
    var commandChooseView: some View {
        HStack(alignment: .top) {
            Picker("", selection: $viewState.selectedToAddCommandType) {
                ForEach(GitCommandType.allCases, id: \.self) {
                    Text($0.name)
                }
            }
            .frame(maxWidth: 120)
            .pickerStyle(.menu)
            .onChange(of: viewState.selectedToAddCommandType) { _, newValue in
                viewState.customCommandText = viewState.selectedToAddCommandType.commandText
            }
            
            VStack(alignment: .leading) {
                TextField("Enter command text", text: $viewState.customCommandText).disabled(!viewState.isSelectedToAddCommandCustom)
                if case .custom = viewState.selectedToAddCommandType {
                    Text("Use $1 for asking input. Only 1 input allowed.")
                        .foregroundStyle(.orange)
                        .font(.itemTitle)
                }
            }
            Button("Add", action: viewState.addCommand)
                .buttonStyle(.borderedProminent)
            
        }.padding([.leading, .trailing])
    }
    
    var keyCatcherView: some View {
        VStack(alignment: .leading) {
            Text("Keyboard shortcuts").font(.dialogSmallTitle).padding(.top, 8)
            Text("You can set up keys that will trigger the command").foregroundStyle(.secondary).font(.itemTitle).padding(.top, 4)
            
            if viewState.triedToEdit {
                Text("Restart the app to apply").foregroundStyle(.orange).font(.itemTitle).padding(.top, 4)
            }
            KeyCaptureView(
                capturedKey: $viewState.capturedKey,
                capturedKeyCode: $viewState.capturedKeyCode,
                modifiers: $viewState.modifiers
            )
            .frame(width: 200, height: 33)
            .overlay(
                KeyDisplayView(key: viewState.capturedKey, keyCode: viewState.capturedKeyCode, modifiers: viewState.modifiers)
                    .padding(.leading, 12.0)
                    .padding([.top, .bottom], 4.0)
                    .allowsHitTesting(false),
                alignment: .leading
            )
        }.padding(.all)
    }
    
    var bottomView: some View {
        HStack(alignment: .bottom) {
            Button("Edit File", action: viewState.editFile)
            Spacer()
            Button("Cancel", action: viewState.close)
            Button("Save", action: viewState.save)
                .buttonStyle(.borderedProminent)
                .disabled(viewState.shortcut.name.isEmpty || viewState.commands.isEmpty)
        }.padding(.all)
    }
    
    var loadingView: some View {
        ProgressView().controlSize(.regular).padding()
    }
}
