import SwiftUI

struct SideBarView<T: ISideBarViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI
    
    var body: some View {
        VStack {
            AnyView(dependencies.projectPickerAssembly.build())
            List(selection: $viewState.sideBarCommand) {
                ForEach(CommandsSection.allCases) { item in
                    Section(item.displayName) {
                        ForEach(item.commands) { command in
                            Label {
                                Text(command.title)
                            } icon: {
                                command.icon.foregroundStyle(.mainOrange)
                            }
                            .tag(command)
                        }
                    }
                }
            }
            Spacer()
            appVersionView
            .padding()
            .modify { content in
                if #available(macOS 26, *) {
                    content.padding()
                } else {
                    content.padding()
                        .background(.cellBackground)
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(.cellBorder, lineWidth: 1)
                        )
                }
            }
        }
        .toolbar(content: {
            if viewState.sideBarCommand.isExecutingCommandAvailable {
                Button {
                    viewState.toggleExecutingState()
                } label: {
                    viewState.isExecuting ? Image.stop : Image.play
                }.disabled(!viewState.generateButtonEnabled)
            }
        })
        .onChange(of: viewState.sideBarCommand) { oldValue, newValue in
            viewState.sideBarCommandDidChange()
        }
    }
    
    var appVersionView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text(Constants.gekoTitle).font(.cellTitle)
                if viewState.isUpdating {
                    ProgressView().controlSize(.small)
                }
                
            }
            Text("Current version: \(viewState.currentAppVersion)").font(.footnote)

            if let lastAvailableVersion = viewState.lastAvailableVersion, lastAvailableVersion != viewState.currentAppVersion {
                Text("Last Available: \(lastAvailableVersion)").font(.footnote)
                Button(action: viewState.updateApp) {
                    HStack {
                        Spacer()
                        Text("Update")
                        Spacer()
                    }
                }.buttonStyle(.borderedProminent).disabled(viewState.isUpdating)
            } else {
                if viewState.lastAvailableVersion != nil, viewState.currentAppVersion == viewState.lastAvailableVersion {
                    Text("You're using the latest version").font(.footnote)
                }
                Button(action: viewState.checkVersionUpdate) {
                    HStack {
                        Spacer()
                        Text("Check update")
                        Spacer()
                    }
                }.buttonStyle(.borderedProminent).disabled(viewState.isUpdating)
            }
        }
    }
}
