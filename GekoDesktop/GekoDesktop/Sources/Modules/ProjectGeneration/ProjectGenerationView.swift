import SwiftUI

struct ProjectGenerationView<T: IProjectGenerationViewStateOutput>: View {
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    var body: some View {
        ScrollView {
            switch viewState.state {
            case .loaded:
                dataView
            case .loading:
                loadingView
            case .error:
                errorView
            case .empty:
                emptyView
            }
        }
        .sheet(isPresented: $viewState.showConfigsEditor) { 
            configEditorView
        }
        .sheet(isPresented: $viewState.showAdditionalOptionsDialog) {
            AnyView(dependencies.additionalOptionsAssembly.build(closeAction: viewState.addCustomFlags))
        }
        .sheet(isPresented: $viewState.showFocusedModulesDialog) {
            AnyView(dependencies.sourcesEditorAssembly.build(closeAction: viewState.chooseFocusedModules))
        }.alert("Command did copied to clipboard!", isPresented: $viewState.showCommandCopiedPopup, actions: { 
            Button { 
                viewState.showCommandCopiedPopup.toggle()
            } label: { 
                Text("Close")
            }
        })
        .onAppear {
            viewState.onAppear()
        }
    }
    
    var emptyView: some View {
        HStack {
            Spacer()
            Text("Select project")
            Spacer()
        }.padding()
    }
    
    var errorView: some View {
        HStack {
            Spacer()
            Text("Error while loading workspace")
            Spacer()
        }.padding()
    }
    
    var loadingView: some View {
        HStack {
            Spacer()
            VStack {
                Text("Loading workspace")
                ProgressView().controlSize(.regular)
            }
            Spacer()
        }.padding()
    }
    
    var dataView: some View {
        VStack {
            configView
            profileView
            if !viewState.schemes.isEmpty {
                schemeView
            }
            optionsView
            destinationView
            focusView
            buildCommandView
        }.padding()
    }
    
    var configView: some View {
        PickerCell(
            title: "Build Plan Config",
            items: Array(viewState.allConfigs),
            disabled: false,
            hasAboutButton: true,
            hasEditButton: true,
            aboutButtonTapped: viewState.aboutConfig,
            editButtonTapped: viewState.openConfigsEditor,
            selectedItem: $viewState.selectedConfig
        ).onChange(of: viewState.selectedConfig) {
            viewState.configDidChanged()
        }
    }
    
    var configEditorView: some View {
        VStack {
            HStack {
                TextField("Name", text: $viewState.newConfigName)
                Button { 
                    viewState.addConfig()
                } label: { 
                    Text("Add")
                }.disabled(viewState.allConfigs.contains(where: { $0 == viewState.newConfigName }) || viewState.newConfigName.isEmpty)
            }.padding()
            ForEach(viewState.allConfigs.sorted()) { config in
                HStack {
                    Text(config)
                    Spacer()
                    if config != "Default" {
                        Image.delete
                            .resizable()
                            .foregroundStyle(.red)
                            .frame(width: 14, height: 16)
                            .onTapGesture {
                                viewState.deleteConfig(config)
                        }
                    }
                }.padding([.leading, .trailing])
                Divider().padding([.leading, .trailing])
            }
            Button { 
                viewState.showConfigsEditor.toggle()
            } label: { 
                Text("Close")
            }.padding(.bottom)
        }.frame(width: 200)
    }
    
    var profileView: some View {
        switch viewState.profiles {
        case .loaded(let array):
            AnyView(PickerCell(
                title: "Profile",
                items: array.map { $0.name },
                disabled: false,
                hasAboutButton: false,
                hasEditButton: false,
                selectedItem: $viewState.selectedProfile
            ).onChange(of: viewState.selectedProfile) {
                viewState.selectedProfileDidChanged()
            })
        case .error:
            AnyView(HStack {
                Text("Profile").font(.cellTitle)
                Spacer()
                Image.danger
                Text("Error while loading profiles")
                Button("Reload") { 
                    viewState.reloadProfiles()
                }
            }
            .padding()
            .background(.cellBackground)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.cellBorder, lineWidth: 1)
            ))
        case .empty:
            AnyView(EmptyView())
        }
    }
    
    var schemeView: some View {
        PickerCell(
            title: "Scheme",
            items: viewState.schemes,
            disabled: false,
            hasAboutButton: false,
            hasEditButton: false,
            selectedItem: $viewState.selectedScheme
        ).onChange(of: viewState.selectedScheme) {
            viewState.selectedSchemeDidChanged()
        }
    }

    var optionsView: some View {
        EditableCell(
            viewModel: EditableCellViewModel(
                title: "Options",
                isEditable: true,
                hasEye: false,
                hasAbout: false,
                editButtonTapped: viewState.openSettingsEditor
            ),
            state: .data(AnyView(optionsDataView))
        )
    }
    
    var optionsDataView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewState.settings) { item in
                VStack {
                    if let index = viewState.index(for: item) {
                        HStack {
                            Toggle(isOn: $viewState.settings[index].value, label: {
                                Text(item.item)
                            }).onChange(of: viewState.settings[index].value) { 
                                viewState.settingDidChanged(item)
                            }.disabled(!item.enabled)
                            Spacer()
                            if GenerationCommands.allCommands.contains(item.item) {
                                Image.about
                                    .resizable()
                                    .foregroundStyle(.gray)
                                    .frame(width: 16, height: 16)
                                    .onTapGesture {
                                        viewState.aboutItem(item.item)
                                    }
                            } else {
                                Image.delete
                                    .resizable()
                                    .foregroundStyle(.red)
                                    .frame(width: 14, height: 16)
                                    .onTapGesture {
                                        viewState.deleteItem(for: item.item)
                                }
                            }
                        }
                        if index < viewState.settings.count - 1 {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }.popover(isPresented: $viewState.showInfoPopover) {
            Text(viewState.popoverInfo).padding().lineLimit(nil).frame(width: 300)
        }
    }
    
    var destinationView: some View {
        PickerCell(
            title: "Deployment Target",
            items: viewState.deploymentTargets,
            disabled: false,
            hasAboutButton: false,
            hasEditButton: false,
            selectedItem: $viewState.selectedDeploymentTarget
        ).onChange(of: viewState.selectedDeploymentTarget) {
            viewState.selectedDeploymentTargetDidChanged()
        }
    }

    var focusView: some View {
        EditableCell(
            viewModel: EditableCellViewModel(
                title: "Focus",
                isEditable: true,
                hasEye: false,
                hasAbout: false,
                editButtonTapped: viewState.chooseFocusedModules
            ),
            state: .data(AnyView(focusDataView))
        )
    }

    var focusDataView: some View {
        VStack(alignment: .leading) {
            if !viewState.focusRegexes.isEmpty {
                VStack(alignment: .leading) {
                    Text("Regular expressions").padding(.bottom, 4.0)
                    ForEach(viewState.focusRegexes) { module in
                        HStack {
                            Image.textformat.foregroundStyle(.gray).bold()
                            Text(module).foregroundStyle(.gray)
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 4.0)
            }
            if !viewState.focusModules.isEmpty {
                Text("Modules").padding(.bottom, 4.0)
                ForEach(viewState.focusModules) { module in
                    HStack {
                        Image.developmentConfigItem.foregroundStyle(.gray)
                        Text(module).foregroundStyle(.gray)
                        Spacer()
                    }
                }
            }
        }
    }
    
    var buildCommandView: some View {
        EditableCell(
            viewModel: EditableCellViewModel(
                title: "Generate command",
                isEditable: false,
                hasEye: false,
                hasAbout: false,
                customButtons: $viewState.customCommands,
                customButtonTapped: viewState.customButtonTapped
            ),
            state: .data(AnyView(buildCommandDataView))
        )
    }
    
    var buildCommandDataView: some View {
        HStack {
            Text(viewState.finalCommand).foregroundStyle(.gray)
            Spacer()
            Image.copy.onTapGesture {
                viewState.copyCommand()
            }
            viewState.commandLoading ?
            Image.stop.onTapGesture {
                viewState.toggleExecutingState()
            } :
            Image.play.onTapGesture {
                viewState.toggleExecutingState()
            }
        }
    }
}  
