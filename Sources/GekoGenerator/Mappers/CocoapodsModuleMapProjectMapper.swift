import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

private let driverKitXcodeSdkFilter = "driverkit"

public final class CocoapodsModuleMapProjectMapper: ProjectMapping {
    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        guard project.projectType == .cocoapods else { return sideEffects }

        for i in 0 ..< project.targets.count {
            let moduleMapDir = project.path
                .appending(component: Constants.DerivedDirectory.name)
                .appending(component: project.targets[i].name)
                .appending(component: Constants.DerivedDirectory.moduleMaps)

            sideEffects.append(contentsOf: try update(
                target: &project.targets[i],
                moduleMapDir: moduleMapDir,
                srcroot: project.sourceRootPath
            ))
        }

        return sideEffects
    }

    private func update(
        target: inout Target,
        moduleMapDir: AbsolutePath,
        srcroot: AbsolutePath
    ) throws -> [SideEffectDescriptor] {
        guard let headers = target.headers?.list else { return [] }

        var moduleMapsToGenerate: [
            PlatformFilter?: (moduleMap: Headers.ModuleMap, umbrella: AbsolutePath?)
        ] = [:]

        for i in 0 ..< headers.count {
            guard let moduleMap = headers[i].moduleMap else { continue }
            let umbrella = headers[i].umbrellaHeader

            var platforms: [PlatformFilter?] = headers[i].compilationCondition.map { Array($0.platformFilters) } ?? []

            if platforms.isEmpty {
                platforms.append(nil)
            }

            for platform in platforms {
                if let (conflictingModuleMap, conflictingUmbrella) = moduleMapsToGenerate[platform] {
                    // thats ok if header lists have the same module map or umbrella value
                    if conflictingModuleMap != moduleMap {
                        logger.warning("Target \(target.name) contains conflicting module map values for platform \(platform?.xcodeprojValue ?? "default"). First module map from headers list will be used.")
                    }
                    if conflictingUmbrella != umbrella {
                        logger.warning("Target \(target.name) contains conflicting umrella values for platform \(platform?.xcodeprojValue ?? "default"). First umbrella from headers list will be used.")
                    }
                    continue
                }

                moduleMapsToGenerate[platform] = (moduleMap, umbrella)
            }
        }

        if moduleMapsToGenerate[.catalyst] != nil && moduleMapsToGenerate[.macos] != nil {
            logger.warning("Target \(target.name) contains conflicting module map values for platforms 'macos' and 'catalyst', because 'catalyst' platform is a variant of 'macos'. Which module map will be used is undefined.")
        }

        var sideEffects: [SideEffectDescriptor] = []

        for (platform, (moduleMap, umbrella)) in moduleMapsToGenerate {
            if target.settings == nil {
                target.settings = .settings()
            }

            switch moduleMap {
            case .absent:
                break
            case let .file(path: moduleMapPath):
                let value = SettingValue.string("$(PODS_TARGET_SRCROOT)/\(moduleMapPath.relative(to: srcroot))")
                target.settings!.base[platform.buildSettingKey(key: "MODULEMAP_FILE")] = value
                target.settings!.base[platform.buildSettingKey(key: "DEFINES_MODULE")] = "YES"
            case .generate:
                // In case we have specific platforms, we should not create default moduleMap
                // By default we always have default cocoapods platform
                if moduleMapsToGenerate.count > 1 && platform == nil {
                    continue
                }

                let platformCaseValue = platform?.xcodeprojValue ?? "default"
                let moduleMapFileName = platform == nil ? "\(target.name).modulemap" : "\(target.name)-\(platformCaseValue).modulemap"
                let moduleMapPath = moduleMapDir.appending(component: moduleMapFileName)

                let value = SettingValue.string("$(PODS_TARGET_SRCROOT)/\(moduleMapPath.relative(to: srcroot))")
                target.settings!.base[platform.buildSettingKey(key: "MODULEMAP_FILE")] = value
                target.settings!.base[platform.buildSettingKey(key: "DEFINES_MODULE")] = "YES"

                let (umbrellaHeaders, excludedHeaders) = headersForUmbrella(
                    from: headers,
                    for: platform
                )

                let umbrellaForModuleMap: AbsolutePath
                if let umbrella {
                    umbrellaForModuleMap = umbrella
                } else {
                    let generatedUmbrellaContent = generateUmbrella(
                        moduleName: target.productName,
                        from: umbrellaHeaders,
                        for: platform
                    )

                    let umbrellaFileName = platform == nil ? "\(target.name)-umbrella.h" : "\(target.name)-\(platformCaseValue)-umbrella.h"
                    let umbrellaPath = moduleMapDir.appending(component: umbrellaFileName)

                    sideEffects.append(.file(.init(
                        path: umbrellaPath, contents: generatedUmbrellaContent.data(using: .utf8), state: .present
                    )))

                    umbrellaForModuleMap = umbrellaPath
                }

                target.headers?.list.append(
                    Headers(
                        public: [umbrellaForModuleMap],
                        compilationCondition: platform.map { .when([$0]) } ?? nil
                    )
                )

                let generatedModuleMapContent = generateModuleMap(
                    moduleName: target.productName,
                    umbrella: umbrellaForModuleMap.basename,
                    excludedPublicHeaders: excludedHeaders
                )

                sideEffects.append(.file(.init(
                    path: moduleMapPath, contents: generatedModuleMapContent.data(using: .utf8), state: .present
                )))
            }
        }

        return sideEffects
    }

    private func generateUmbrella(
        moduleName: String,
        from headers: [AbsolutePath],
        for platform: PlatformFilter?
    ) -> String {
        let headersContent = headers.map { "#import \"\($0.basename)\"" }.sorted().joined(separator: "\n")

        let fileContent = """
            #ifdef __OBJC__
            \(platform.platformHeader)
            #else
            #ifndef FOUNDATION_EXPORT
            #if defined(__cplusplus)
            #define FOUNDATION_EXPORT extern "C"
            #else
            #define FOUNDATION_EXPORT extern
            #endif
            #endif
            #endif

            \(headersContent)

            FOUNDATION_EXPORT double \(moduleName)VersionNumber;
            FOUNDATION_EXPORT const unsigned char \(moduleName)VersionString[];
            """

        return fileContent
    }

    private func headersForUmbrella(
        from headers: borrowing [Headers],
        for platform: PlatformFilter?
    ) -> (include: [AbsolutePath], exclude: [AbsolutePath]) {
        var include: Set<AbsolutePath> = []
        var exclude: Set<AbsolutePath> = []

        for i in 0 ..< headers.count {
            // platform is default if compilationCondition == nil or platformFilters are empty
            let isDefault = headers[i].compilationCondition?.platformFilters.isEmpty != false
            var isSuitable = false
            if let platform, headers[i].compilationCondition?.platformFilters.contains(platform) == true {
                isSuitable = true
            }

            if isSuitable || isDefault {
                include.formUnion(headers[i].public?.files ?? [])
            } else {
                exclude.formUnion(headers[i].public?.files ?? [])
            }
        }

        include.subtract(exclude)

        return (include: Array(include), exclude: Array(exclude))
    }

    private func generateModuleMap(
        moduleName: String,
        umbrella: String?,
        excludedPublicHeaders: [AbsolutePath]
    ) -> String {
        let umbrellaString: String = umbrella.map {
            "umbrella header \"\($0)\""
        } ?? ""

        let excludedHeaders = excludedPublicHeaders.map {
            "exclude header \"\($0.basename)\""
        }

        let fileContent = """
        framework module \(moduleName) {
            \(umbrellaString)
            \(excludedHeaders.isEmpty ? "" : excludedHeaders.joined(separator: "\n    "))

            export *
            module * { export * }
        }
        """

        return fileContent
    }
}

private extension Optional<PlatformFilter> {
    var platformHeader: String {
        switch self {
        case .ios, .tvos, .catalyst, .none:
            return "#import <UIKit/UIKit.h>"
        case .macos:
            return "#import <Cocoa/Cocoa.h>"
        case .driverkit, .watchos, .visionos:
            return "#import <Foundation/Foundation.h>"
        }
    }

    func buildSettingKey(key: String) -> String {
        switch self {
        case .none:
            return key
        case .ios: 
            return "\(key)[sdk=\(Platform.iOS.xcodeDeviceOrSimulatorSDK)*]"
        case .macos, .catalyst:
            return "\(key)[sdk=\(Platform.macOS.xcodeDeviceOrSimulatorSDK)*]"
        case .watchos:
            return "\(key)[sdk=\(Platform.watchOS.xcodeDeviceOrSimulatorSDK)*]"
        case .tvos:
            return "\(key)[sdk=\(Platform.tvOS.xcodeDeviceOrSimulatorSDK)*]"
        case .visionos:
            return "\(key)[sdk=\(Platform.visionOS.xcodeDeviceOrSimulatorSDK)*]"
        case .driverkit:
            return "\(key)[sdk=\(driverKitXcodeSdkFilter)*]"
        }
    }
}
