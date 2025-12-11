/// Possible products types.
public enum Product: String, Codable, Equatable, CaseIterable {
    /// An application.
    case app
    /// A static library.
    case staticLibrary = "static_library"
    /// A dynamic library.
    case dynamicLibrary = "dynamic_library"
    /// A dynamic framework.
    case framework
    /// A static framework.
    case staticFramework
    /// A unit tests bundle.
    case unitTests = "unit_tests"
    /// A UI tests bundle.
    case uiTests = "ui_tests"
    /// A custom bundle. (currently only iOS resource bundles are supported).
    case bundle
    /// A command line tool (macOS platform only).
    case commandLineTool
    /// An application extension.
    case appExtension = "app_extension"
    /// A Watch application. (watchOS platform only) .
    case watch2App
    /// A Watch application extension. (watchOS platform only).
    case watch2Extension
    /// A TV Top Shelf Extension.
    case tvTopShelfExtension
    /// An iMessage extension. (iOS platform only)
    case messagesExtension
    /// A sticker pack extension.
    case stickerPackExtension = "sticker_pack_extension"
    /// An appClip. (iOS platform only).
    case appClip
    //    case watchApp
    //    case watchExtension
    //    case tvIntentsExtension
    //    case messagesApplication
    /// An XPC. (macOS platform only).
    case xpc
    /// An system extension. (macOS platform only).
    case systemExtension
    /// An ExtensionKit extension.
    case extensionKitExtension = "extension_kit_extension"
    /// A Swift Macro
    /// Although Apple doesn't officially support Swift Macro Xcode Project targets, we
    /// enable them by adding a command line tool target, a target dependency in
    /// the dependent targets, and the right build settings to use the macro executable.
    case macro
    /// Aggregate target a spacial type of target that lets you build a group of target at once
    /// An aggregate target has no associated product and no build rules
    case aggregateTarget = "aggregate_target"
    
    /// Returns true if the target can be ran.
    var runnable: Bool {
        switch self {
        case
            .app,
            .appClip,
            .commandLineTool,
            .watch2App,
            .appExtension,
            .messagesExtension,
            .stickerPackExtension,
            .tvTopShelfExtension,
            .watch2Extension,
            .extensionKitExtension,
            .macro:
            return true
        case
            .bundle,
            .systemExtension,
            .dynamicLibrary,
            .framework,
            .staticFramework,
            .staticLibrary,
            .unitTests,
            .uiTests,
            .xpc,
            .aggregateTarget:
            return false
        }
    }
    
    var testsBundle: Bool {
        self == .uiTests || self == .unitTests
    }
    
    var isStatic: Bool {
        [.staticLibrary, .staticFramework].contains(self)
    }

    var isFramework: Bool {
        [.framework, .staticFramework].contains(self)
    }

    var isDynamic: Bool {
        [.framework, .dynamicLibrary].contains(self)
    }

    var canHostTests: Bool {
        [.app, .appClip, .watch2App].contains(self)
    }
}
