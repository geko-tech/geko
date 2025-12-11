import SwiftUI

struct GekoDesktopSettingsView<T: IGekoDesktopSettingsViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    var body: some View {
        ScrollView {
            ForEach(viewState.settings) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.title).font(.cellTitle).fontWeight(.semibold)
                        Text(item.description).font(.footnote).foregroundStyle(.gray)
                    }
                    Spacer()
                    Button(action: {
                        viewState.settingDidTapped(item)
                    }, label: {
                        Text(item.actionTitle)
                    }).disabled(!viewState.enabledSettings.contains(item))
                }
                .padding()
                .background(.cellBackground)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.cellBorder, lineWidth: 1)
                )
            }
            .padding()
        }.onAppear(perform: {
            viewState.onAppear()
        })
        .sheet(isPresented: $viewState.showVersionsDialog) {
            versionsListDialog
        }
    }
    
    var versionsListDialog: some View {
        VStack {
            Text("Available versions").font(.cellTitle).padding([.leading, .top])
            versionsList
            bottomView
        }
        .frame(minWidth: 400, minHeight: 600, maxHeight: 800)
    }
    
    var versionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(viewState.availableVersions.enumerated().reversed()), id: \.offset) { index, version in
                    HStack {
                        Text(version).padding(.leading)
                        if version == Constants.appVersion {
                            Text("Current")
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.toolbarBackround))
                        }
                        Spacer()
                        Button { 
                            viewState.versionDidSelected(version)
                        } label: { 
                            Text("Select")
                        }
                    }
                    Divider().padding(.leading)
                }
            }.padding()
        }
    }
    
    var bottomView: some View {
        HStack(alignment: .bottom) {
            Spacer()
            Button("Cancel", action: viewState.closeVersionDialog)
        }.padding([.bottom, .trailing])
    }
}
