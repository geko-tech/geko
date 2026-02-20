import Foundation
import ProjectDescription
import GekoSupport

private extension String {
    static let loadGekoPluginSymbol = "loadGekoPlugin"
    static let objcClassWarningRegex = #"objc\[\d+\]: Class \S+ is implemented in both"#
}

private extension Int {
    static let pluginMagicNumber = 3716326
}

public protocol GekoPluginLoading: AnyObject {
    func loadGekoPlugin(
        mapperPath: WorkspaceMapperPluginPath,
        generationOptions: Workspace.GenerationOptions
    ) async throws -> GekoPlugin
}

public final class GekoPluginLoader: GekoPluginLoading {

    private let strErrFilter: StdErrFiltering

    public init(
        strErrFilter: StdErrFiltering = StdErrFilter(),
    ) {
        self.strErrFilter = strErrFilter
    }

    public func loadGekoPlugin(
        mapperPath: WorkspaceMapperPluginPath,
        generationOptions: Workspace.GenerationOptions
    ) async throws -> GekoPlugin {
        let pluginLib = try await dlopenFilter(mapperPath: mapperPath, generationOptions: generationOptions)

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

    private func dlopenFilter(mapperPath: WorkspaceMapperPluginPath, generationOptions: Workspace.GenerationOptions) async throws -> UnsafeMutableRawPointer {
        if generationOptions.suppressObjcDuplicateClassWarningsDuringPluginLoading {
            let objcClassWarningRegex = try Regex(.objcClassWarningRegex)

            return try await strErrFilter.filter(
                isLineIncluded: { try objcClassWarningRegex.firstMatch(in: $0) == nil },
                block: { try dlopenPlugin(mapperPath: mapperPath) },
            )
        } else {
            return try dlopenPlugin(mapperPath: mapperPath)
        }
    }

    private func dlopenPlugin(mapperPath: WorkspaceMapperPluginPath) throws -> UnsafeMutableRawPointer {
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

        return pluginLib
    }
}
