import Foundation

final class ApplicationSettingsService {
    
    static let shared = ApplicationSettingsService()
    
    var gitObserverDisabled: Bool {
        get {
            ud.bool(forKey: "gitObserverDisabled")
        }
        set {
            ud.setValue(newValue, forKey: "gitObserverDisabled")
        }
    }
    
    var showTrace: Bool {
        get {
            ud.bool(forKey: "showTrace")
        }
        set {
            ud.setValue(newValue, forKey: "showTrace")
        }
    }
    
    private let ud = UserDefaults()
}
