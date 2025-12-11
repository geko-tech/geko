import SwiftUI

struct AdditionalOptionsEditorView<T: IAdditionalOptionsEditorViewStateOutput>: View {
    // MARK: - Attributes
    
    @StateObject var viewState: T

    var body: some View {
        VStack {
            optionsView.padding(.top)
            bottomView
        }
        .frame(minWidth: 300, minHeight: 200, maxHeight: 400)
    }
    
    var optionsView: some  View {
        TextEditor(text: $viewState.options)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .autocorrectionDisabled(true)
    }
    
    var bottomView: some View {
        HStack(alignment: .bottom) {
            Spacer()
            Button("Cancel", action: viewState.close)
            Button("Apply", action: viewState.apply)
                .buttonStyle(.borderedProminent)
        }.padding([.bottom, .trailing])
    }
}
