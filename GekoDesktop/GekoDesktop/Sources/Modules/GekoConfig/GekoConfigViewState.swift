import SwiftUI

protocol IGekoConfigViewStateOutput: ObservableObject {
    var state: ConfigState { get }
    
    func onAppear()
    func editTapped()
    func reloadConfig()
}

protocol IGekoConfigViewStateInput: AnyObject {
    func stateDidChanged(_ newState: ConfigState)
}

@Observable
final class GekoConfigViewState: IGekoConfigViewStateInput & IGekoConfigViewStateOutput {
    
    var state: ConfigState = .empty
    
    private let presenter: IGekoConfigPresenter
    
    init(presenter: IGekoConfigPresenter) {
        self.presenter = presenter
    }
    
    func onAppear() {
        presenter.onAppear()
    }
    
    func editTapped() {
        presenter.edit()
    }
    
    func stateDidChanged(_ newState: ConfigState) {
        state = newState
    }
    
    func reloadConfig() {
        presenter.reload()
    }
}
