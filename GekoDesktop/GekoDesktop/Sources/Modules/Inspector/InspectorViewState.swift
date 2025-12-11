import SwiftUI

enum InspectorState {
    case tree([ProjectTree])
    case empty
    case loading
    case error
}

protocol IInspectorViewStateOutput: ObservableObject {
    var state: InspectorState { get }
    var showAllModules: Bool { get }
    var cacheButtonDisabled: Bool { get }
    
    func eyeButtonTapped()
    func reload()
}

protocol IInspectorViewStateInput: AnyObject {
    func stateDidUpdated(_ newState: InspectorState, cacheAvailable: Bool)
}

@Observable
final class InspectorViewState: IInspectorViewStateInput & IInspectorViewStateOutput {
    // MARK: - Attributes
    
    var state: InspectorState = .empty
    var showAllModules: Bool = false
    var cacheButtonDisabled: Bool = true
    
    private let presenter: IInspectorPresenter
    
    init(presenter: IInspectorPresenter) {
        self.presenter = presenter
    }
    
    func eyeButtonTapped() {
        showAllModules.toggle()
        presenter.rebuildTree(hideCachedModules: !showAllModules)
    }
    
    // MARK: - IInspectorViewStateInput
    
    func stateDidUpdated(_ newState: InspectorState, cacheAvailable: Bool) {
        state = newState
        switch newState {
        case .tree(_):
            /// If the user has selected "cached only" and disabled the cache, we force the display of the entire tree.
            if !cacheAvailable && !showAllModules {
                showAllModules = true
            }
        case .empty, .loading, .error:
            break
        }
        cacheButtonDisabled = !cacheAvailable
    }
    
    func reload() {
        presenter.reload()
    }
}
