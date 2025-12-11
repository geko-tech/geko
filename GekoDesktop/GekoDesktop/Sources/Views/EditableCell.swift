import SwiftUI

struct CustomCommand {
    let name: String
    var isLoading: Bool
}

struct EditableCellViewModel {
    let title: String
    let isEditable: Bool
    let hasEye: Bool
    let hasAbout: Bool
    let hasRefresh: Bool
    let customButtons: Binding<[CustomCommand]>?
    
    var showError: Bool = false
    
    var editButtonTapped: (() -> Void)?
    var eyeButtonTapped: (() -> Void)?
    var aboutButtonTapped: (() -> Void)?
    var refreshButtonTapped: (() -> Void)?
    var customButtonTapped: ((Int) -> Void)?
    
    init(
        title: String,
        isEditable: Bool = false,
        hasEye: Bool = false,
        hasAbout: Bool = false,
        hasRefresh: Bool = false,
        customButtons: Binding<[CustomCommand]>? = nil,
        editButtonTapped: (() -> Void)? = nil,
        eyeButtonTapped: (() -> Void)? = nil,
        aboutButtonTapped: (() -> Void)? = nil,
        refreshButtonTapped: (() -> Void)? = nil,
        customButtonTapped: ((Int) -> Void)? = nil
    ) {
        self.title = title
        self.isEditable = isEditable
        self.hasEye = hasEye
        self.hasAbout = hasAbout
        self.hasRefresh = hasRefresh
        self.customButtons = customButtons
        self.editButtonTapped = editButtonTapped
        self.eyeButtonTapped = eyeButtonTapped
        self.aboutButtonTapped = aboutButtonTapped
        self.refreshButtonTapped = refreshButtonTapped
        self.customButtonTapped = customButtonTapped
    }
}

struct EditableCell: View {
    
    enum EditableCellState {
        case data(AnyView)
        case error(String)
        case empty
    }
    
    let viewModel: EditableCellViewModel
    let state: EditableCellState

    var body: some View {
        VStack {
            headerView
            switch state {
            case .data(let anyView):
                Divider().padding([.bottom], 8.0)
                HStack(alignment: .bottom) {
                    anyView
                    if viewModel.hasAbout {
                        Spacer()
                        aboutButton
                    }
                }
                
            case .error(let error):
                Divider().padding([.bottom], 8.0)
                AnyView(errorView(error))
            case .empty:
                EmptyView()
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
    
    var headerView: some View {
        HStack {
            Text(viewModel.title).font(.cellTitle)
            Spacer()
            HStack(spacing: 10) {
                if let customButtons = viewModel.customButtons?.wrappedValue {
                    ForEach(Array(customButtons.enumerated()), id: \.offset) { index, customButton in
                        if customButton.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(action: {
                                viewModel.customButtonTapped?(index)
                            }, label: {
                                Text(customButton.name)
                            }).buttonStyle(.link)
                        }
                    }
                }
                if viewModel.hasRefresh {
                    refreshButton
                }
                if viewModel.hasEye {
                    eyeButton
                }
                if viewModel.isEditable {
                    editButton
                }
            }
        }
    }
    
    func errorView(_ error: String) -> any View {
        HStack {
            Spacer()
            Image.danger.foregroundStyle(.red)
            Text(error).foregroundStyle(.red)
            Spacer()
            if viewModel.hasAbout {
                aboutButton
            }
        }
    }
    
    var editButton: some View {
        Button {
            viewModel.editButtonTapped?()
        } label: { 
            Image.edit.resizable().frame(width: 16, height: 16)
        }.buttonStyle(.plain)
    }

    var eyeButton: some View {
        Button {
            viewModel.eyeButtonTapped?()
        } label: { 
            Image.visible.resizable().frame(width: 24, height: 16)
        }.buttonStyle(.plain)
    }
    
    var aboutButton: some View {
        Button {
            viewModel.aboutButtonTapped?()
        } label: {
            Image.about.resizable().frame(width: 16, height: 16)
        }.buttonStyle(.plain)
    }
    
    var refreshButton: some View {
        Button {
            viewModel.refreshButtonTapped?()
        } label: { 
            Image.refresh.resizable().frame(width: 16, height: 20)
        }.buttonStyle(.plain)
    }
}

