import SwiftUI

protocol ISourcesEditorViewOutput: ObservableObject {
    var modulesProvider: any ISourcesEditorModulesProvider { get set }
    
    func onAppear()
    func close()
    func apply()
}

protocol ISourcesEditorViewInput: AnyObject {
    func dataDidUpdated(modules: [String], userModules: [String], userRegexs: [String])
}

@Observable
final class SourcesEditorViewState: ISourcesEditorViewInput & ISourcesEditorViewOutput {
    
    var modulesProvider: any ISourcesEditorModulesProvider
    
    private let presenter: ISourcesEditorPresenter
    private var closeAction: () -> Void
    
    init(presenter: ISourcesEditorPresenter, closeAction: @escaping () -> Void) {
        self.presenter = presenter
        self.closeAction = closeAction
        self.modulesProvider = SourcesEditorModulesProvider(
            userModules: [],
            userRegex: [],
            modules: []
        )
    }
    
    func onAppear() {
        presenter.loadData()
    }
    
    func close() {
        closeAction()
    }
    
    func apply() {
        presenter.save(userModules: modulesProvider.selectedModules.map { $0.name }, userRegexes: modulesProvider.regexes)
        closeAction()
    }
    
    func dataDidUpdated(modules: [String], userModules: [String], userRegexs: [String]) {
        modulesProvider = SourcesEditorModulesProvider(
            userModules: userModules,
            userRegex: userRegexs,
            modules: modules
        )
    }
}
