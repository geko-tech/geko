import Foundation
import ProjectDescription

extension Config {
    /// Returns the default Geko configuration.
    public static var `default`: Config {
        Config(
            compatibleXcodeVersions: .all,
            cloud: nil,
            cache: nil,
            swiftVersion: nil,
            plugins: [],
            generationOptions: .options(
                resolveDependenciesWithSystemScm: false,
                disablePackageVersionLocking: false,
                staticSideEffectsWarningTargets: .all
            ),
            preFetchScripts: [],
            preGenerateScripts: [],
            postGenerateScripts: [],
            cocoapodsUseBundler: false
        )
    }
}
