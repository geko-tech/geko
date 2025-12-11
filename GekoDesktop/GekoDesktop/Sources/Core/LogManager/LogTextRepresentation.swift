import Foundation

struct LogTextRepresentation {
    let additionalInfo: [String: AnyHashable]
    var commands: [String] = []
    
    func content() -> String {
        var content = ""
        content += "\nVersion: \(Constants.appVersion)\n"
        content += "Arguments:\n \(commands.joined(separator: "\n"))"
        content += "\n\(additionalInfo.map { "\($0.key): \($0.value)"}.joined(separator: "\n"))\n"
        return content
    }
}
