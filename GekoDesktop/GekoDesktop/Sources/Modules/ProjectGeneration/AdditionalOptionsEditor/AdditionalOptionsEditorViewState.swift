import SwiftUI

protocol IAdditionalOptionsEditorViewStateOutput: ObservableObject {
    var options: String { get set }

    func apply()
    func close()
}

protocol IAdditionalOptionsEditorViewStateInput: AnyObject {
    func dataDidUpdated(_ option: String)
}

@Observable
final class AdditionalOptionsEditorViewState: IAdditionalOptionsEditorViewStateInput & IAdditionalOptionsEditorViewStateOutput {
    
    var options: String = ""
    
    private let presenter: IAdditionalOptionsEditorPresenter
    private var closeAction: () -> Void
    
    init(presenter: IAdditionalOptionsEditorPresenter, closeAction: @escaping () -> Void) {
        self.presenter = presenter
        self.closeAction = closeAction
    }
    
    func apply() {
        presenter.saveData(option: options)
        closeAction()
        options = ""
    }
    
    func close() {
        closeAction()
        options = ""
    }
    
    func dataDidUpdated(_ option: String) {
        self.options = options
    }
}
