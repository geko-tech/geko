import SwiftUI
import AppKit

struct KeyCaptureView: NSViewRepresentable {
    @Binding var capturedKey: String?
    @Binding var capturedKeyCode: UInt16?
    @Binding var modifiers: EventModifiers?

    func makeNSView(context: Context) -> NSView {
        let textView = KeyCatcher()
        
        textView.configure()
        textView.onKeyCapture = { key, mods, keyCode in
            capturedKey = key
            capturedKeyCode = keyCode
            modifiers = mods
        }
        return textView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyCatcher: NSTextView {
        var onKeyCapture: ((String, EventModifiers, UInt16) -> Void)?

        func configure() {
            isEditable = true
            isSelectable = true
            textContainerInset = NSSize(width: 2, height: 10)
            isHorizontallyResizable = false
            isVerticallyResizable = false
            
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        }
        
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            self.window?.makeFirstResponder(self)
        }

        override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
            return false
        }
        
        override func keyDown(with event: NSEvent) {
            guard let key = event.charactersIgnoringModifiers, !key.isEmpty else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var emods = EventModifiers.from(flags: mods)
            if !key.isEmpty, emods.isEmpty {
                emods = .command
            }
            onKeyCapture?(key.lowercased(), emods, event.keyCode)
        }
    }
}
