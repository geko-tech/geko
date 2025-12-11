public struct Configuration: Codable, Equatable {
    let name: String
    var profile: String
    var scheme: String?
    var deploymentTarget: String
    var options: [String: Bool]
    var focusModules: [String]
    var userRegex: [String] = []
    
    public init(
        name: String,
        profile: String,
        scheme: String? = nil,
        deploymentTarget: String,
        options: [String : Bool],
        focusModules: [String],
        userRegex: [String] = []
    ) {
        self.name = name
        self.profile = profile
        self.scheme = scheme
        self.deploymentTarget = deploymentTarget
        self.options = options
        self.focusModules = focusModules
        self.userRegex = userRegex
    }
}
