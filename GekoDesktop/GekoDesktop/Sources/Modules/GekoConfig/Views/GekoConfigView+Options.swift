import SwiftUI
import struct ProjectDescription.Config

extension GekoConfigView {
    func buildInstallOptionsView(_ config: Config) -> any View {
        buildOptionsView(config.installOptions.info())
    }
    
    func buildGenerateOptionsView(_ config: Config) -> any View {
        buildOptionsView(config.generationOptions.info())
    }
    
    func buildOptionsView(_ options: [String: String]) -> any View {
        HStack {
            VStack(alignment: .leading) {
                ForEach(options.map { $0.key }) { key in
                    if let value = options[key], !value.isEmpty {
                        HStack {
                            Text(key).foregroundStyle(.gray)
                            Text(value)
                        }
                    }
                }
            }
            Spacer()
        }
    }
}

fileprivate extension ProjectDescription.Config.InstallOptions {
    func info() -> [String: String] {
        [
            "passthroughSwiftPackageManagerArguments": "\(passthroughSwiftPackageManagerArguments.joined(separator: ", "))"
        ]
    }
}

fileprivate extension ProjectDescription.Config.GenerationOptions {
    func info() -> [String: String] {
        [
            "resolveDependenciesWithSystemScm": "\(self.resolveDependenciesWithSystemScm)",
            "disablePackageVersionLocking": "\(self.disablePackageVersionLocking)",
            "clonedSourcePackagesDirPath": "\(self.clonedSourcePackagesDirPath ?? "nil")",
            "staticSideEffectsWarningTargets": "\(self.staticSideEffectsWarningTargets)",
            "enforceExplicitDependencies": "\(self.enforceExplicitDependencies)",
            "convertPathsInPodspecsToBuildableFolders": "\(self.convertPathsInPodspecsToBuildableFolders)",
            "useOldLinkableDependencies": "\(self.useOldLinkableDependencies)",
            "addAstPathsToLinker": "\(self.addAstPathsToLinker)"
        ]
    }
}
