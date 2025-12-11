final class ProjectInfo: Codable {
    var selectedConfigName: String
    
    init(selectedConfigName: String) {
        self.selectedConfigName = selectedConfigName
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedConfigName = try container.decode(String.self, forKey: .selectedConfigName)
    }
}
