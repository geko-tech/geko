import SwiftUI

protocol IWelcomeViewStateOutput: ObservableObject {
    var items: [WelcomeItem] { get }
    var isLoading: Bool { get }
    
    func onAppear()
    func itemTapped(_ item: WelcomeItem)
}

protocol IWelcomeViewStateInput: AnyObject {
    func didUpdateItems(_ items: [WelcomeItem])
    func updateLoadingState(_ newState: Bool)
}

@Observable
final class WelcomeViewState: IWelcomeViewStateInput & IWelcomeViewStateOutput {
    // MARK: - Attributes

    var items: [WelcomeItem] = []
    var isLoading: Bool = false
    
    private let presenter: IWelcomePresenter
    
    // MARK: - Initialization

    init(presenter: IWelcomePresenter) {
        self.presenter = presenter
    }
    
    func onAppear() {
        presenter.prepareItems()
    }
    
    func itemTapped(_ item: WelcomeItem) {
        presenter.itemTapped(item)
    }
    
    // MARK: - IWelcomeViewStateInput

    func didUpdateItems(_ items: [WelcomeItem]) {
        self.items = items
    }
    
    func updateLoadingState(_ newState: Bool) {
        self.isLoading = newState
    }
}

