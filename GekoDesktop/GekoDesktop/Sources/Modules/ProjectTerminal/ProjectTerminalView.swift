import SwiftUI

struct ProjectTerminalView<T: IProjectTerminalViewStateOutput>: View {
    // MARK: - Attributes
    
    @Environment(DependenciesAssembly.self) private var dependencies: DependenciesAssembly
    @StateObject var viewState: T
    
    // MARK: - UI
    
    var body: some View {
        viewState.terminalViewWrapper
    }
}
