import SwiftUI
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.PluginLocation

extension GekoConfigView {
    func pluginsDataView(_ plugins: [PluginLocation]) -> any View {
        VStack(alignment: .leading) {
            ForEach(plugins) { plugin in
                AnyView(plugin.pluginInfo())
                Divider()
            }
            Spacer()
        }
    }
}

fileprivate extension ProjectDescription.PluginLocation {
    func pluginInfo() -> any View {
        switch type {
        case .local(let path, _):
            Text("<local> \(path.pathString)").foregroundStyle(.gray)
        case .gitWithTag(let url, let tag, _):
            Text("<git> \(url) tag: \(tag)").foregroundStyle(.gray)
        case .gitWithSha(let url, let sha, _):
            Text("<git> \(url) sha: \(sha)").foregroundStyle(.gray)
        case .remote(let urls, _):
            Text("<remote> \(urls.map { "\($0.key) - \($0.value)"}.joined(separator: "\n"))").foregroundStyle(.gray)
        case .remoteGekoArchive(let archive):
            Text("<gekoArchive> \(archive.name) \(archive.version)").foregroundStyle(.gray)
        }
    }
    
    func urlBaseName(url: String) -> String {
        if let absPath = try? AbsolutePath(validating: url) {
            return absPath.basenameWithoutExt
        } else {
            return url
        }
    }
}

extension ProjectDescription.PluginLocation: @retroactive Identifiable {
    public var id: String {
        self.description
    }
}
