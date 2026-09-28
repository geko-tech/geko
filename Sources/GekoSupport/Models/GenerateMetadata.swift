import Foundation

public struct GenerateMetadata: Codable {
    public let workspaceName: String
    public let cacheEnabled: Bool
    public let focusedTargets: Set<String>
    public let allTestTargets: [XCTestPlan.TestTarget]

    public init(
        workspaceName: String,
        cacheEnabled: Bool,
        focusedTargets: Set<String>,
        allTestTargets: [XCTestPlan.TestTarget]
    ) {
        self.workspaceName = workspaceName
        self.cacheEnabled = cacheEnabled
        self.focusedTargets = focusedTargets
        self.allTestTargets = allTestTargets
    }
}
