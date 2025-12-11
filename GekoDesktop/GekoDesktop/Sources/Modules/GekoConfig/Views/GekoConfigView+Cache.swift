import SwiftUI
import struct ProjectDescription.Cache

extension GekoConfigView {
    func buildCacheDataView(_ cache: Cache) -> any View {
        HStack {
            VStack(alignment: .leading) {
                if let version = cache.version {
                    Text("Version: \(version)")
                }
                ForEach(cache.profiles) { profile in
                    Text(profile.name).font(.cellTitle)
                    HStack {
                        Text("Configuraton").foregroundStyle(.gray)
                        Text(profile.configuration)
                    }
                    HStack {
                        Text("cachingTests").foregroundStyle(.gray)
                        Text("\(profile.cachingTests)")
                    }
                    if !profile.platforms.isEmpty {
                        HStack {
                            Text("Platforms").foregroundStyle(.gray)
                            Text("[\(profile.platforms.map { $0.key }.map { $0.caseValue }.joined(separator: ", "))]")
                        }
                    }
                    if !profile.scripts.isEmpty {
                        HStack {
                            Text("Scripts").foregroundStyle(.gray)
                            Text(profile.scripts.map { $0.name }.joined(separator: "\n"))
                        }
                    }
                    ForEach(profile.options.info().map { $0.key}) { optionKey in
                        if let value = profile.options.info()[optionKey] {
                            HStack {
                                Text(optionKey).foregroundStyle(.gray)
                                Text(value)
                            }
                        }
                    }
                    Divider()
                }
            }
            Spacer()
        }
    }
    
    func buildCacheView(_ cache: Cache) -> any View {
        EditableCell(
            viewModel: EditableCellViewModel(title: "Cache Info"),
            state: .data(AnyView(buildCacheDataView(cache)))
        )
    }
}

fileprivate extension ProjectDescription.Cache.Profile.Options {
    func info() -> [String: String] {
        [
            "onlyActiveResourcesInBundles": "\(self.onlyActiveResourcesInBundles)",
            "exportCoverageProfiles": "\(self.exportCoverageProfiles)",
            "swiftModuleCacheEnabled": "\(self.swiftModuleCacheEnabled)"
        ]
    }
}

extension ProjectDescription.Cache.Profile: @retroactive Identifiable {
    public var id: String {
        self.name
    }
}
