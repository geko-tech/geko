import Foundation

extension String {
    var version: String? {
        guard let range = self.range(of: #"[0-9]{1,}\.[0-9]{1,}.{0,1}[0-9]{0,}"#, options: .regularExpression) else {
            return nil
        }
        return String(self[range])
    }
    
    var branch: String? {
        self.split(separator: " ").last?.replacingOccurrences(of: "\r", with: "")
    }

    func removeNewLines() -> String {
        self.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
    }
    
    func addNewLine() -> String {
        "\(self)\r\n"
    }
}
