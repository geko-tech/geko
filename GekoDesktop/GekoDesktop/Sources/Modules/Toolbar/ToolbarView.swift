import SwiftUI

struct ToolbarView<T: IToolbarViewStateOutput>: View {
    // MARK: - Attributes
        
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI

    var body: some View {
        HStack {
        }.padding([.leading, .trailing], 8)
        .onAppear(perform: {
            viewState.onAppear()
        })
    }
    
    func buildSelectProjectButton() -> any View {
        Button(action: viewState.chooseProjectDirectory, label: {
            HStack(alignment: .center) {
                Image.appLogo
                    .resizable()
                    .frame(width: 24, height: 24)
                Text("Select Project").frame(height: 24)
                Image.rightChevron.resizable().frame(width: 4, height: 12).padding([.top, .leading], 2)
            }
        }).buttonStyle(ToolbarButtonStyle())
    }
    
    func buildProjectButton(text: String) -> any View {
        Button(action: viewState.chooseProjectDirectory, label: {
            HStack(alignment: .center) {
                Image.appLogo
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(text).frame(height: 24)
                Image.rightChevron.resizable().frame(width: 4, height: 12)
                    .padding([.top, .leading, .trailing], 4)
            }
        }).buttonStyle(ToolbarButtonStyle())
    }
    
    func buildGitButton(text: String) -> any View {
        HStack(alignment: .center, spacing: 0) {
            Image.branch
                .frame(width: 16, height: 16)
            Text(text).frame(height: 24)
        }
    }
}

private extension ToolbarView {
    struct ToolbarButtonStyle: ButtonStyle {
        func makeBody(configuration: Self.Configuration) -> some View {
            configuration.label
                .padding(2)
                .foregroundColor(.toolbarButtonTitle)
                .background(configuration.isPressed ? Color.cellBackground : Color.toolbarButtonBackround)
                .cornerRadius(6.0)
        }
    }
}
