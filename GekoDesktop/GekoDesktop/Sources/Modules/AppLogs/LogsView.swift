import SwiftUI

struct LogsView<T: ILogsViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI

    var body: some View {
        ScrollView {
            ForEach(viewState.readLogs()) { fileName in
                HStack {
                    Text(fileName)
                    Spacer()
                    Button(action: {
                        viewState.openLogsDirectory()
                    }, label: {
                        Text("Show in finder")
                    })
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
        }
    }
}
