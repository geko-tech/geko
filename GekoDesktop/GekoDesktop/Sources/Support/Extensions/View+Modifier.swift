import SwiftUI

extension View {
    @ViewBuilder
    func modify(@ViewBuilder transform: (Self) -> some View) -> some View {
        transform(self)
    }
}
