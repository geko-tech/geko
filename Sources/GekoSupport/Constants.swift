import Foundation

public enum Constants {
    public static let versionFileName = ".geko-version"
    public static let binName = "geko"
    public static let gitRepositoryURL = "https://github.com/geko-tech/geko.git"
    public static let githubAPIURL = "https://api.github.com"
    public static let version = "0.35.0"
    public static let projectDescriptionVersion = "release/0.14.0"
    public static let isStage = true
    public static let execSupportMinVersion = "0.6.0"
    public static let bundleName : String = "geko.zip"
    public static let trueValues: [String] = ["1", "true", "TRUE", "yes", "YES"]
    public static let gekoDirectoryName: String = "Geko"

    public static let helpersDirectoryName: String = "ProjectDescriptionHelpers"
    public static let signingDirectoryName: String = "Signing"

    public static let masterKey = "master.key"
    public static let encryptedExtension = "encrypted"
    public static let templatesDirectoryName: String = "Templates"
    public static let stencilsDirectoryName: String = "Stencils"
    public static let vendorDirectoryName: String = "vendor"
    public static let gekoGeneratedFileName = ".geko-generated"
    public static let projectProfilesFileName = "project_profiles.yml"

    /// The cache version.
    /// This should change only when it changes the logic to map a `GekoGraph.Target` to a cached build artifact.
    /// Changing this results in changing the target hash and hence forcing a rebuild of its artifact.
    public static let cacheVersion = "1.3.0"
    public static let cacheLatesBuildFileName = "latest_build"

    public enum GekoUserCacheDirectory {
        public static let name = ".geko"
        public static let versionsDir = "Versions"
    }

    public enum DependenciesDirectory {
        public static let dependenciesFileName = "Dependencies.swift"
        public static let name = "Dependencies"
        public static let graphName = "graph.json"
        public static let lockfilesDirectoryName = "Lockfiles"
        public static let packageSwiftName = "Package.swift"
        public static let cocoapodsLockfileName = "Cocoapods.lock"
        public static let cocoapodsSandboxName = "CocoapodsSandbox.lock"
        public static let packageSandboxName = "PackageSandbox.lock"
        public static let packageResolvedName = "Package.resolved"
        public static let packageBuildDirectoryName = ".build"
        public static let workspaceStateName = "workspace-state.json"
        public static let swiftPackageManagerDirectoryName = "SwiftPackageManager"
        public static let swiftinterfacesDirectoryName = "SwiftInterfaces"
        public static let spmCheckouts = "checkouts"
    }

    public enum DerivedDirectory {
        public static let name = "Derived"
        public static let infoPlists = "InfoPlists"
        public static let entitlements = "Entitlements"
        public static let moduleMaps = "ModuleMaps"
        public static let sources = "Sources"
        public static let resources = "Resources"
        public static let signingKeychain = "signing.keychain"
        public static let dependenciesDerivedDirectory = "geko-derived"
    }

    public enum AsyncQueue {
        public static let directoryName: String = "Queue"
    }

    /// Pass these variables to make custom configuration of geko
    /// These variables are not supposed to be used by end users
    /// But only eg. for acceptance tests and other cases needed internally
    public enum EnvironmentVariables {
        public static let verbose = "GEKO_CONFIG_VERBOSE"
        public static let colouredOutput = "GEKO_CONFIG_COLOURED_OUTPUT"
        public static let versionsDirectory = "GEKO_CONFIG_VERSIONS_DIRECTORY"
        public static let forceConfigCacheDirectory = "GEKO_CONFIG_FORCE_CONFIG_CACHE_DIRECTORY"
        public static let automationPath = "GEKO_CONFIG_AUTOMATION_PATH"
        public static let queueDirectory = "GEKO_CONFIG_QUEUE_DIRECTORY"
        public static let cacheManifests = "GEKO_CONFIG_CACHE_MANIFESTS"
        public static let statsOptOut = "GEKO_CONFIG_STATS_OPT_OUT"
        public static let githubAPIToken = "GEKO_CONFIG_GITHUB_API_TOKEN"
        public static let detailedLog = "GEKO_CONFIG_DETAILED_LOG"
        public static let osLog = "GEKO_CONFIG_OS_LOG"
        /// `gekoBinaryPath` is used for specifying the exact geko binary in geko tasks.
        public static let gekoBinaryPath = "GEKO_CONFIG_BINARY_PATH"

        public static let impactAnalysisEnabled = "GEKO_IMPACT_ANALYSIS_ENABLED"
        public static let impactAnalysisSourceRef = "GEKO_IMPACT_SOURCE_REF"
        public static let impactAnalysisTargetRef = "GEKO_IMPACT_TARGET_REF"
        public static let impactAnalysisDebug = "GEKO_IMPACT_ANALYSIS_DEBUG"
        public static let impactAnalysisChangedTargets = "GEKO_IMPACT_ANALYSIS_CHANGED_TARGET_NAMES"
        public static let impactAnalysisChangedProducts = "GEKO_IMPACT_ANALYSIS_CHANGED_PRODUCT_NAMES"
        public static let inspectSourceRef = "GEKO_INSPECT_SOURCE_REF"
        public static let inspectTargetRef = "GEKO_INSPECT_TARGET_REF"
        public static let cloudAccessKey = "GEKO_CLOUD_ACCESS_KEY"
        public static let cloudSecretKey = "GEKO_CLOUD_SECRET_KEY"
        public static let statsOutput = "GEKO_CONFIG_STATS_OUTPUT"
        public static let cacheTargetHashesSave = "GEKO_CONFIG_CACHE_TARGET_HASHES_SAVE"
        public static let forceConfigLogDirectory = "GEKO_CONFIG_LOG_STORAGE_DIR"
        public static let cocoapodsCacheDirectory = "GEKO_CONFIG_COCOAPODS_CACHE_DIR"
        public static let cocoapodsRepoCacheDirectory = "GEKO_CONFIG_COCOAPODS_REPO_CACHE_DIR"
        public static let requestTimeout = "GEKO_REQUEST_TIMEOUT"
        public static let swiftModuleCache = "GEKO_SWIFTMODULE_CACHE_ENABLED"
        public static let forceBuildCacheDirectory = "GEKO_CONFIG_BUILD_CACHE_DIR"
        public static let impactAnalysisSymlinksSupportEnabled = "GEKO_IMPACT_ANALYSIS_SYMLINKS_SUPPORT_ENABLED"
    }

    public enum AutogeneratedScheme {
        public static let binariesSchemeNamePrefix: String = "ProjectCache-Binaries"
        public static let bundlesSchemeNamePrefix: String = "ProjectCache-Bundles"
    }

    public enum Plugins {
        public static let executables = "Executables"
        public static let plugisSandbox = "PluginsSandbox.lock"
        public static let mappers = "Mappers"
        public static let infoFileName = "info.json"
    }
}
