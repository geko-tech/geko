import SwiftUI

struct KeyView: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)))
    }
}

struct KeyDisplayView: View {
    var key: String?
    var keyCode: UInt16?
    var modifiers: EventModifiers?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayStrings(modifiers), id: \.self) { part in
                KeyView(text: part)
            }
            
            if let key, !key.isEmpty {
                Text(" + ")
                KeyView(text: displayString(keyCode: keyCode) ?? key.uppercased())
            }
        }
    }

    func displayStrings(_ modifiers: EventModifiers?) -> [String] {
        guard let modifiers else { return [] }
        
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }
        
        return parts
    }

    func displayString(keyCode: UInt16?) -> String? {
        guard let keyCode else { return nil }
        
        switch keyCode {
        case 123: return "←"  // left arrow
        case 124: return "→"  // right arrow
        case 125: return "↓"  // down arrow
        case 126: return "↑"  // up arrow
        case 36:  return "↩︎"  // return
        case 48:  return "⇥"  // tab
        case 49:  return "␣"  // space
        case 51:  return "⌫"  // delete
        case 53:  return "⎋"  // escape
        default:
            return nil
        }
    }
}
