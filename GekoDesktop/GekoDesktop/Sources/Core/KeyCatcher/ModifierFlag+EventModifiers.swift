import SwiftUI

extension EventModifiers {

    static func from(flags: NSEvent.ModifierFlags) -> EventModifiers {
        var raw = 0
        if flags.contains(.command)  { raw |= Self.command.rawValue }
        if flags.contains(.shift)    { raw |= Self.shift.rawValue }
        if flags.contains(.option)   { raw |= Self.option.rawValue }
        if flags.contains(.control)  { raw |= Self.control.rawValue }
        return EventModifiers(rawValue: raw)
    }
}
