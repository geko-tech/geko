import SwiftUI

struct TerminalViewWrapper: NSViewRepresentable {

    private let terminalView: TerminalView

    init(terminalView: TerminalView) {
        self.terminalView = terminalView
    }

    func makeNSView(context: Context) -> NSView {
        terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
