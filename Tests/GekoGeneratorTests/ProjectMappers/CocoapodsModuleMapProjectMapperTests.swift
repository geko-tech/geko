import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoGenerator
import XCTest

import GekoGraphTesting
import GekoSupportTesting

final class CocoapodsModuleMapProjectMapperTests: GekoUnitTestCase {
    func test_generatesModuleMapAndUmbrella() throws {
        let subject = CocoapodsModuleMapProjectMapper()
        var sideTable = ProjectSideTable()

        var project = Project.test(
            targets: [
                .test(
                    name: "Target",
                    headers: HeadersList(list: [
                        Headers(
                            public: "public_header.h",
                            moduleMap: .generate,
                            private: "private_header.h",
                            project: "project_header.h"
                        )
                    ])
                )
            ],
            projectType: .cocoapods
        )

        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        let moduleMapPath = try project.path.appending(RelativePath(validating: "Derived/Target/ModuleMaps/Target.modulemap"))
        let expectedModuleMapSettingValue: SettingValue = "$(PODS_TARGET_SRCROOT)/\(moduleMapPath.relative(to: project.sourceRootPath))"

        XCTAssertEqual(project.targets[0].settings?.base["MODULEMAP_FILE"], expectedModuleMapSettingValue)

        let expected: [SideEffectDescriptor] = [
            .file(FileDescriptor(
                path: try project.path.appending(RelativePath(validating: "Derived/Target/ModuleMaps/Target-umbrella.h")),
                contents:
                """
                #ifdef __OBJC__
                #import <UIKit/UIKit.h>
                #else
                #ifndef FOUNDATION_EXPORT
                #if defined(__cplusplus)
                #define FOUNDATION_EXPORT extern "C"
                #else
                #define FOUNDATION_EXPORT extern
                #endif
                #endif
                #endif

                #import "public_header.h"

                FOUNDATION_EXPORT double TargetVersionNumber;
                FOUNDATION_EXPORT const unsigned char TargetVersionString[];
                """.data(using: .utf8),
                state: .present
            )),
            .file(FileDescriptor(
                path: moduleMapPath,
                contents:
                """
                framework module Target {
                    umbrella header "Target-umbrella.h"
                    

                    export *
                    module * { export * }
                }
                """.data(using: .utf8),
                state: .present
            )),
        ]

        XCTAssertEqual(sideEffects, expected)
    }

    func test_generatesModuleMap_and_usesExistingUmbrella() throws {
        let subject = CocoapodsModuleMapProjectMapper()
        var sideTable = ProjectSideTable()

        var project = Project.test(
            targets: [
                .test(
                    name: "Target",
                    headers: HeadersList(list: [
                        Headers(
                            public: "/Project/headers/public_header.h",
                            umbrellaHeader: "/Project/headedrs/existing_umbrella.h",
                            moduleMap: .generate,
                            private: "/Project/headers/private_header.h",
                            project: "/Project/headers/project_header.h"
                        )
                    ])
                )
            ],
            projectType: .cocoapods
        )

        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        let moduleMapPath = try project.path.appending(RelativePath(validating: "Derived/Target/ModuleMaps/Target.modulemap"))
        let expectedModuleMapSettingValue: SettingValue = "$(PODS_TARGET_SRCROOT)/\(moduleMapPath.relative(to: project.sourceRootPath))"

        XCTAssertEqual(project.targets[0].settings?.base["MODULEMAP_FILE"], expectedModuleMapSettingValue)

        let expected: [SideEffectDescriptor] = [
            .file(FileDescriptor(
                path: moduleMapPath,
                contents:
                """
                framework module Target {
                    umbrella header "existing_umbrella.h"
                    

                    export *
                    module * { export * }
                }
                """.data(using: .utf8),
                state: .present
            )),
        ]

        XCTAssertEqual(sideEffects, expected)
    }

    func test_usesExistingModuleMap() throws {
        let subject = CocoapodsModuleMapProjectMapper()
        var sideTable = ProjectSideTable()

        let moduleMapPath: FilePath = "/Project/module.modulemap"

        var project = Project.test(
            targets: [
                .test(
                    name: "Target",
                    headers: HeadersList(list: [
                        Headers(
                            public: "/Project/headers/public_header.h",
                            umbrellaHeader: "/Project/headers/existing_umbrella.h",
                            moduleMap: .file(path: moduleMapPath),
                            private: "/Project/headers/private_header.h",
                            project: "/Project/headers/project_header.h"
                        )
                    ])
                )
            ],
            projectType: .cocoapods
        )

        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        let expectedModuleMapSettingValue: SettingValue = "$(PODS_TARGET_SRCROOT)/\(moduleMapPath.relative(to: project.sourceRootPath))"

        XCTAssertEqual(project.targets[0].settings?.base["MODULEMAP_FILE"], expectedModuleMapSettingValue)
        XCTAssertEqual(sideEffects, [])
    }

    func test_doesNotGenerateModuleMapForNonCocoapodsProjects() throws {
        let subject = CocoapodsModuleMapProjectMapper()
        var sideTable = ProjectSideTable()

        var project = Project.test(
            targets: [
                .test(
                    name: "Target",
                    headers: HeadersList(list: [
                        Headers(
                            public: "public_header.h",
                            moduleMap: .generate,
                            private: "private_header.h",
                            project: "project_header.h"
                        )
                    ])
                )
            ],
            projectType: .geko
        )

        var sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        XCTAssertNil(project.targets[0].settings?.base["MODULEMAP_FILE"])
        XCTAssertEqual(sideEffects, [])

        project.projectType = .spm

        sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        XCTAssertNil(project.targets[0].settings?.base["MODULEMAP_FILE"])
        XCTAssertEqual(sideEffects, [])
    }
}
