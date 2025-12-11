import Foundation

extension URLComponents {

    var netloc: String {
        var result = host ?? ""
        if let port {
            result += ":\(port)"
        }
        return result
    }

    func canonicalQueryString() -> String {
        queryItems?
            .sorted(by: { $0.name < $1.name })
            .map { $0.name.queryEncode() + "=" + ($0.value?.queryEncode() ?? "") }
            .joined(separator: "&") ?? ""
    }
}
