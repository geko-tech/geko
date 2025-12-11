import SwiftUI

enum ToolbarState {
    case empty
    case data(projectName: String, branch: String?)
}

protocol IToolbarViewStateInput: AnyObject {
    func updateToolbarState(_ newState: ToolbarState)
}

protocol IToolbarViewStateOutput: ObservableObject {
    var toolbarState: ToolbarState { get }

    func onAppear()
    func chooseProjectDirectory()
    func chooseGitBranch()
}

@Observable
final class ToolbarViewState: IToolbarViewStateInput & IToolbarViewStateOutput {
    // MARK: - Attributes
    
    private let presenter: IToolbarPresenter
    
    var toolbarState: ToolbarState = .empty
    
    // MARK: - Initialization
    
    init(presenter: IToolbarPresenter) {
        self.presenter = presenter
    }
    
    // MARK: - IToolbarViewStateInput
    
    func updateToolbarState(_ newState: ToolbarState) {
        toolbarState = newState
    }
    
    // MARK: - IToolbarViewStateInput
    
    func chooseProjectDirectory() {
        presenter.chooseProjectDirectory()
    }
    
    func chooseGitBranch() {
        presenter.chooseGitBranch()
    }
    
    func onAppear() {
        presenter.onAppear()
    }
}
