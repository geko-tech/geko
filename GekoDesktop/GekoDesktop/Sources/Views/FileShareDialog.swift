import SwiftUI

struct FileShareDialog: View {
    let fileName: String?
    let description: String?
    let url: URL?
    let cancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Your file").font(.dialogTitle)
                
            Text(fileName ?? "").foregroundStyle(.blue).padding(.top, 2.0)
            Text(description ?? "").padding([.top, .bottom], 8.0).foregroundStyle(.gray)
            HStack {
                Button(action: {
                    cancel()
                }, label: {
                    Text("Cancel")
                })
                .buttonStyle(.bordered)
                Spacer()
                if let url {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }, label: {
                        Text("Show in Finder")
                    })
                    .buttonStyle(.borderedProminent)
                    
                    ShareLink("Share", item: url)
                }
            }.padding(.top, 4.0)
        }
        .frame(maxWidth: 400)
        .padding()
    }
}
