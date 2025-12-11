import Foundation

enum CocoapodsSource {
    case cdn(url: String)
    case git(url: String, ref: String)
    case path(path: String)
    case gitRepo(url: String)
}

extension CocoapodsSource {
    var url: String {
        switch self {
        case let .cdn(url):
            return url
        case let .git(url, _):
            return url
        case let .path(path):
            return path
        case let .gitRepo(url):
            return url
        }
    }

    var lockfileUrl: String {
        switch self {
        case let .cdn(url):
            return url
        case let .git(url, ref):
            return "\(url)@\(ref)"
        case let .path(path):
            return path
        case let .gitRepo(url):
            return url
        }
    }

    var isCDN: Bool {
        if case .cdn = self {
            return true
        }
        return false
    }
}
