import SwiftUI

struct InspectorView<T: IInspectorViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI
    
    var body: some View {
        switch viewState.state {
        case .tree(let tree):
            TreeView(projectTree: tree)
                .toolbar(content: {
                    HStack {
                        Button(action: {
                            viewState.eyeButtonTapped()
                        }, label: {
                            viewState.showAllModules ? Image.visible : Image.invisible
                        }).disabled(viewState.cacheButtonDisabled)
                    }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { newValue in
                        toolbarY = newValue.maxY
                    }
                })
        case .empty:
            emptyView
        case .loading:
            loadingView
        case .error:
            errorView
        }
    }
    
    var loadingView: some View {
        VStack {
            ProgressView().controlSize(.regular).padding(.bottom)
            Text("Loading")
        }.padding()
    }
    
    var emptyView: some View {
        Text("No data")
    }
    
    var errorView: some View {
        VStack {
            Text("Error while load graph")
            Button("Reload") {
                viewState.reload()
            }
        }.padding()
    }

}
