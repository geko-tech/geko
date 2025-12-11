import Foundation

protocol IUserInfoProvider: AnyObject {
    var gekoVersion: String? { get set }
    
    func clearCache()
}

final class UserInfoProvider: IUserInfoProvider {
    enum Keys: String, CaseIterable {
        case gekoVersion
    }
    
    var gekoVersion: String? {
        get {
            ud.string(forKey: Keys.gekoVersion.rawValue)
        }
        set {
            ud.set(newValue, forKey: Keys.gekoVersion.rawValue)
        }
    }
    
    private let ud = UserDefaults()

    func clearCache() {
        for key in Keys.allCases {
            ud.removeObject(forKey: key.rawValue)
        }
    }
}
