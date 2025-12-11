import Foundation
import struct ProjectDescription.AbsolutePath
import GekoAutomation
import GekoCoreTesting
import GekoGraph
import GekoLoader
import XCTest
@testable import GekoCore
@testable import GekoGenerator
@testable import GekoKit
@testable import GekoSupportTesting

final class ProjectMapperFactoryTests: GekoUnitTestCase {
    var subject: ProjectMapperFactory!

    override func setUp() {
        super.setUp()
        subject = ProjectMapperFactory()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_default_contains_target_mapper() {
        // When
        let got = subject.default()

        // Then

        XCTAssertContainsElementOfType(got, TargetActionDisableShowEnvVarsProjectMapper.self)
    }

    // Currently this mapper is disabled
//    func test_default_when_bundle_accessors_are_enabled() {
//        // When
//        let got = subject.default()
//
//        // Then
//
//        XCTAssertContainsElementOfType(got, ResourcesProjectMapper.self)
//        XCTAssertContainsElementOfType(got, ResourcesProjectMapper.self, after: DeleteDerivedDirectoryProjectMapper.self)
//    }

    func test_default_contains_the_ide_template_macros_mapper() {
        // When
        let got = subject.default()

        // Then
        XCTAssertContainsElementOfType(got, IDETemplateMacrosMapper.self)
    }

    func test_automation_contains_the_source_root_path_project_mapper() {
        // When
        let got = subject.automation(skipUITests: true)

        // Then
        XCTAssertContainsElementOfType(got, SourceRootPathProjectMapper.self)
    }

    func test_automation_contains_the_skip_ui_tests_mapper_when_skip_ui_tests_is_true() {
        // When
        let got = subject.automation(skipUITests: true)

        // Then
        XCTAssertContainsElementOfType(got, SkipUITestsProjectMapper.self)
    }

    func test_automation_doesnt_contain_the_skip_ui_tests_mapper_when_skip_ui_tests_is_false() {
        // When
        let got = subject.automation(skipUITests: false)

        // Then
        XCTAssertDoesntContainElementOfType(got, SkipUITestsProjectMapper.self)
    }

    func test_cache_contain_resource_bundle_active_resources_mapper() {
        // When
        let got = subject.cache(cacheProfile: .test())

        // Then
        XCTAssertContainsElementOfType(got, ResourceBundleActiveResourcesProjectMapper.self)
    }

    func test_cache_contain_default_mappers() {
        // When
        let defaultCount = subject.default().count
        let got = subject.cache(cacheProfile: .test()).count

        // Then
        XCTAssertEqual(got, defaultCount + 2)
    }

    func test_cache_contain_export_coverage_profiles_mapper() {
        // When
        let got = subject.cache(cacheProfile: .test())

        // Then
        XCTAssertContainsElementOfType(got, ExportCoverageProfilesProjectMapper.self)
    }
}
