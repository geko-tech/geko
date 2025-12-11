import Foundation

protocol IWorkspaceSettingsProviderDelegate: AnyObject {
    func configDidChanged(_ config: ConfigState)
    func workspaceDidChanged(_ workspace: WorkspaceState)
    func generationSettingsDidChanged(_ settings: [String: Bool])
    func selectedSchemeDidChanged(_ schemeName: String)
    func selectedProfileNameDidChanged(_ profileName: String)
    func selectedDeploymentTargetDidChanged(_ target: String)
    func additionalOptionsDidChanged(_ options: [String])
    func selectedModulesDidChanged(_ modules: [String])
    func cachedDidInvalidated()
}

extension IWorkspaceSettingsProviderDelegate {
    func configDidChanged(_ config: ConfigState) {}
    func workspaceDidChanged(_ workspace: WorkspaceState) {}
    func generationSettingsDidChanged(_ settings: [String: Bool]) {}
    func selectedSchemeDidChanged(_ schemeName: String) {}
    func selectedProfileNameDidChanged(_ profileName: String) {}
    func selectedDeploymentTargetDidChanged(_ target: String) {}
    func additionalOptionsDidChanged(_ options: [String]) {}
    func selectedModulesDidChanged(_ modules: [String]) {}
    func cachedDidInvalidated() {}
}
