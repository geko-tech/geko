import Foundation
import ProjectDescription

private extension String {
    static let loadGekoPluginSymbol = "loadGekoPlugin"
}

private extension Int {
    static let pluginMagicNumber = 3716326
}

public protocol GekoPluginLoading: AnyObject {
    func loadGekoPlugin(mapperPath: WorkspaceMapperPluginPath) throws -> GekoPlugin
}

public final class GekoPluginLoader: GekoPluginLoading {

    public init() {}

    public func loadGekoPlugin(mapperPath: WorkspaceMapperPluginPath) throws -> GekoPlugin {
        guard let pluginLib = dlopen(mapperPath.path.pathString, RTLD_NOW | RTLD_LOCAL) else {
            let dlopenErrorText = if let errorCStr = dlerror() {
                String(cString: errorCStr)
            } else {
                "Unknown error when loading dynamic library."
            }
            throw WorkspaceMapperPluginLoaderError.errorLoadingPlugin(
                pluginName: mapperPath.name,
                mapperPath: mapperPath.path.pathString,
                dlopenErrorText: dlopenErrorText
            )
        }

        guard let symbol = dlsym(pluginLib, String.loadGekoPluginSymbol) else {
            throw WorkspaceMapperPluginLoaderError.errorLoadingSymbol(
                symbolName: .loadGekoPluginSymbol,
                pluginName: mapperPath.name,
                path: mapperPath.path.pathString
            )
        }

        typealias LoadPluginFunction = @convention(c) () -> UnsafeMutableRawPointer

        let loadPluginFunc: LoadPluginFunction = unsafeBitCast(symbol, to: LoadPluginFunction.self)
        let pluginPointer = loadPluginFunc()
        let gekoPlugin = Unmanaged<GekoPlugin>.fromOpaque(pluginPointer).takeRetainedValue()

        if gekoPlugin.magicNumber != .pluginMagicNumber {
            throw WorkspaceMapperPluginLoaderError.errorPluginMagicNumber(
                expected: .pluginMagicNumber,
                got: gekoPlugin.magicNumber
            )
        }

        return gekoPlugin
    }
}
