import SwiftUI

struct PickerCell: View {

    let title: String
    var items: [String]
    var disabled: Bool
    var hasAboutButton: Bool
    var hasEditButton: Bool
    var aboutButtonTapped: (() -> Void)?
    var editButtonTapped: (() -> Void)?
    @Binding var selectedItem: String

    var body: some View {
        HStack {
            Text(title).font(.cellTitle)
            Spacer()
            Picker("", selection: $selectedItem) {
                ForEach(items, id: \.self) {
                    Text($0)
                }
            }
            .disabled(disabled)
            .frame(maxWidth: 120)
            .pickerStyle(.menu)
            if hasAboutButton {
                aboutButton
            }
            if hasEditButton {
                editButton
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
    
    var aboutButton: some View {
        Button {
            aboutButtonTapped?()
        } label: { 
            Image.about.resizable().frame(width: 16, height: 16)
        }.buttonStyle(.plain)
    }
    
    var editButton: some View {
        Button {
            editButtonTapped?()
        } label: { 
            Image.edit.resizable().frame(width: 16, height: 16)
        }.buttonStyle(.plain)
    }
}

