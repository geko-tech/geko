import Foundation
import ProjectDescription

/// It represents the WorkspaceSettings.xcsettings contained in xcworkspace.
public struct XCWorkspaceSettingsPlist: Codable, Hashable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case derivedDataLocationStyle = "DerivedDataLocationStyle"
        case derivedDataCustomLocation = "DerivedDataCustomLocation"
    }
    
    public enum DerivedDataLocationStyle: String, Hashable, Codable {
        case `default` = "Default"
        case workspaceRelativePath = "WorkspaceRelativePath"
        case absolutePath = "AbsolutePath"
    }
    public let derivedDataLocationStyle: DerivedDataLocationStyle
    public let derivedDataCustomLocation: String?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.derivedDataLocationStyle = try container.decode(XCWorkspaceSettingsPlist.DerivedDataLocationStyle.self, forKey: .derivedDataLocationStyle)
        self.derivedDataCustomLocation = try container.decodeIfPresent(String.self, forKey: .derivedDataCustomLocation)
    }
}
