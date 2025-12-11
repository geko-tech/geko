import SwiftUI

struct ModulesListView: View {

    let title: String
    let didSelectAction: (ModuleItem) -> Void
    @Binding var modules: [ModuleItem]

    var body: some View {
        LazyVStack(alignment: .leading) {
            Text(title).font(.cellTitle)
            ForEach(Array(modules.enumerated()), id: \.offset) { index, item in
                VStack {
                    AnyView(toggleView(index: index, item: item))
                }
            }
        }
    }
    
    func toggleView(index: Int, item: ModuleItem) -> any View {
        HStack {
            if item.isInRegex {
                VStack(alignment: .leading) {
                    HStack(spacing: 0.0) {
                        Image.checkmarkFill.foregroundStyle(.green).padding(.trailing, 4.0)
                        Image.framework.foregroundStyle(.yellow).padding(.trailing, 8.0)
                        Text(item.name)
                    }
                    HStack(spacing: 0.0) {
                        Text("Included in regex ")
                            .font(.footnote).bold().foregroundStyle(.gray)
                        Text("\(item.includedInRegexes.joined(separator: ", "))")
                            .font(.footnote).foregroundStyle(.gray)
                    }
                }
            } else {
                Toggle(
                    isOn: $modules[index].isSelected,
                    label: {
                        HStack {
                            Image.framework.foregroundStyle(.yellow)
                            Text(item.name)
                        }
                        
                    }
                ).onChange(of: modules[index].isSelected) {
                    didSelectAction(item)
                }
            }
            Spacer()
        }
    }
}
