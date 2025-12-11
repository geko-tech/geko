import ProjectDescription

public struct GekoPluginWithParams {
    public let name: String
    public let plugin: GekoPlugin
    public let params: [String: String]
    
    public init(
        name: String,
        plugin: GekoPlugin,
        params: [String: String]
    ) {
        self.name = name
        self.plugin = plugin
        self.params = params
    }
}

public protocol GekoPluginStoring {
    var gekoPlugins: [GekoPluginWithParams] { get }
    func register(gekoPlugins: [GekoPluginWithParams])
}

public final class GekoPluginStorage: GekoPluginStoring {
    
    public static var shared: GekoPluginStorage = GekoPluginStorage()
    public var gekoPlugins: [GekoPluginWithParams] = []
    
    public func register(gekoPlugins: [GekoPluginWithParams]) {
        self.gekoPlugins = gekoPlugins
    }
}
