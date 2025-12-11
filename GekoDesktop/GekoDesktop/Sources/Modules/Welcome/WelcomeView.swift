import SwiftUI

struct WelcomeView<T: IWelcomeViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    var body: some View {
        ScrollView {
            if viewState.isLoading {
                loadingView
            } else {
                itemsView
            }
        }.onAppear(perform: {
            viewState.onAppear()
        })
    }
    
    var loadingView: some View {
        HStack(alignment: .center) {
            Text("Setup Environment")
            Spacer()
            ProgressView().controlSize(.small)
        }
        .padding()
        .background(.cellBackground)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(.cellBorder, lineWidth: 1)
        )
        .padding()
    }
    
    var itemsView: some View {
        VStack(spacing: 12) {
            ForEach(viewState.items) { item in
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.cellTitle).fontWeight(.semibold)
                        if let descrption = item.description {
                            Text(descrption)
                        }
                    }
                    Spacer()
                    if let actionTitle = item.actionTitle {
                        Button(actionTitle) {
                            viewState.itemTapped(item)
                        }.disabled(viewState.isLoading)
                    }
                }
                .padding()
                .background(.cellBackground)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.cellBorder, lineWidth: 1)
                )
            }
        }.padding()
    }
}
