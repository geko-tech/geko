import SwiftUI
import struct ProjectDescription.Config

struct GekoConfigView<T: IGekoConfigViewStateOutput>: View {

    @StateObject var viewState: T
    
    var body: some View {
        ScrollView {
            VStack {
                switch viewState.state {
                case .empty:
                    emptyView
                case .loading:
                    loadingView
                case .loaded(let config):
                    AnyView(buildConfigView(config))
                case .error:
                    errorView
                }  
            }.padding()
        }.onAppear {
            viewState.onAppear()
        }
    }
    
    var emptyView: some View {
        VStack {
            Spacer()
            Text("Project not selected or Config.swift not exist")
            Spacer()
        }
    }
    
    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.regular).padding(.bottom)
            Text("Loading")
            Spacer()
        }
    }
    
    var errorView: some View {
        VStack {
            Spacer()
            Text("Error while loading config")
            Button(action: viewState.reloadConfig) { 
                Text("Reload")
            }
            Spacer()
        }
    }
    
    func buildConfigView(_ config: Config) -> any View {
        VStack {
            AnyView(buildInfoView(config))
            if let cache = config.cache {
                AnyView(buildCacheView(cache))
            }
            if !config.installOptions.passthroughSwiftPackageManagerArguments.isEmpty {
                EditableCell(
                    viewModel: EditableCellViewModel(title: "Install Options"),
                    state: .data(AnyView(buildInstallOptionsView(config)))
                )
            }
            EditableCell(
                viewModel: EditableCellViewModel(title: "Generation Options"),
                state: .data(AnyView(buildGenerateOptionsView(config)))
            )
            if !config.plugins.isEmpty {
                EditableCell(
                    viewModel: EditableCellViewModel(title: "Plugins"),
                    state: .data(AnyView(pluginsDataView(config.plugins)))
                )
            }
            if !config.preFetchScripts.isEmpty {
                EditableCell(
                    viewModel: EditableCellViewModel(title: "Pre-fetch Scripts"),
                    state: .data(AnyView(scriptsDataView(config.preFetchScripts)))
                )
            }
            if !config.preGenerateScripts.isEmpty {
                EditableCell(
                    viewModel: EditableCellViewModel(title: "Pre-generate Scripts"),
                    state: .data(AnyView(scriptsDataView(config.preGenerateScripts)))
                )    
            }
            if !config.postGenerateScripts.isEmpty {
                EditableCell(
                    viewModel: EditableCellViewModel(title: "Post-generate Scripts"),
                    state: .data(AnyView(scriptsDataView(config.postGenerateScripts)))
                )    
            }
        }
    }
    
    func buildInfoView(_ config: Config) -> any View {
        EditableCell(viewModel: EditableCellViewModel(
            title: "Info",
            isEditable: true,
            hasRefresh: true,
            editButtonTapped: viewState.editTapped,
            refreshButtonTapped: viewState.reloadConfig
        ), state: .data(AnyView(buildInfoDataView(config))))
    }
    
    func buildInfoDataView(_ config: Config) -> any View {
        VStack {
            HStack {
                Image.xcode.resizable().frame(width: 16, height: 16)
                Text("Xcode")
                Text(config.compatibleXcodeVersions.description)
                if let swiftVersion = config.swiftVersion {
                    Image.swift.resizable().frame(width: 16, height: 16).foregroundStyle(.red)
                    Text("Swift")
                    Text(swiftVersion.description)
                }
                Spacer()
            }
            if let cloud = config.cloud, let url = URL(string: cloud.url) {
                HStack {
                    Image.cloud.resizable().frame(width: 16, height: 12)
                    Text("bucket")
                    Link(cloud.bucket, destination: url)
                    Spacer()
                }
            }
        }
    }

    func scriptsDataView(_ scripts: [Config.Script]) -> any View {
        HStack {
            VStack(alignment: .leading) {
                ForEach(scripts.map { $0.scriptBody() }) { script in
                    Text(script).foregroundStyle(.gray)
                }
            }
            Spacer()
        }
    }
}

fileprivate extension ProjectDescription.Config.Script {
    func scriptBody() -> String {
        switch self {
        case .script(let shellScript):
            return "<script> \(shellScript.script)"
        case .plugin(let executablePlugin):
            return "<plugin> \(executablePlugin.name)"
        }
    }
}
