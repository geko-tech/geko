import SwiftUI

struct RegexListView: View {
    let removeAction: (Int) -> Void
    @Binding var regexes: [String]

    var body: some View {
        LazyVStack(alignment: .leading) {
            VStack {
                ForEach(Array(regexes.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Image.textformat.foregroundStyle(.gray).bold()
                        VStack(alignment: .leading) {
                            Text(item)
                        }
                        Spacer()
                        Image.delete
                            .resizable()
                            .foregroundStyle(.red)
                            .frame(width: 14, height: 16)
                            .onTapGesture {
                                removeAction(index)
                            }
                            .padding([.trailing], 8)
                    }
                }
            }
        }
    }
}
