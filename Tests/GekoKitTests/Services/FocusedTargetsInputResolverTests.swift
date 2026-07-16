import Foundation
import GekoSupport
import XCTest

@testable import GekoKit
@testable import GekoSupportTesting

final class FocusedTargetsInputResolverTests: GekoUnitTestCase {
    private var subject: FocusedTargetsInputResolver!

    override func setUp() {
        super.setUp()
        subject = FocusedTargetsInputResolver(fileHandler: fileHandler)
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_resolve_returnsPositionalSources_whenPlanIsNotProvided() throws {
        let got = try subject.resolve(
            sources: ["App", "Feature.*"],
            planPath: nil
        )

        XCTAssertEqual(got, Set(["App", "Feature.*"]))
    }

    func test_resolve_returnsEmptySet_whenNeitherInputIsProvided() throws {
        let got = try subject.resolve(sources: [], planPath: nil)

        XCTAssertEqual(got, [])
    }

    func test_resolve_readsRelativePlan_andAppliesLineSyntax() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        let content = "# Application\r\n App \r\n\r\n// Features\r\nFeature.*\r\nApp\r\nFeature//Literal\r\nFeature#Literal\r\n"
        try FileHandler.shared.write(content, path: planPath, atomically: true)

        let got = try subject.resolve(sources: [], planPath: "focus.plan")

        XCTAssertEqual(
            got,
            Set(["App", "Feature.*", "Feature//Literal", "Feature#Literal"])
        )
    }

    func test_resolve_readsAbsolutePlan() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "absolute.plan")
        try FileHandler.shared.write("App\n", path: planPath, atomically: true)

        let got = try subject.resolve(sources: [], planPath: planPath.pathString)

        XCTAssertEqual(got, Set(["App"]))
    }

    func test_resolve_combinesPlanAndPositionalSources_andRemovesDuplicates() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        try FileHandler.shared.write(
            "App\nFeature.*\n",
            path: planPath,
            atomically: true
        )

        let got = try subject.resolve(
            sources: ["App", "Extra"],
            planPath: planPath.pathString
        )

        XCTAssertEqual(got, Set(["App", "Feature.*", "Extra"]))
    }

    func test_resolve_fails_whenPlanDoesNotExist() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "missing.plan")

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.planNotFound(planPath)
        )
    }

    func test_resolve_fails_whenPlanIsDirectory() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        try FileHandler.shared.createFolder(planPath)

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.planIsDirectory(planPath)
        )
    }

    func test_resolve_fails_whenPlanIsEmpty() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        try FileHandler.shared.write(
            "",
            path: planPath,
            atomically: true
        )

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.emptyPlan(planPath)
        )
    }

    func test_resolve_fails_whenPlanIsEmpty_evenWithPositionalSources() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        try FileHandler.shared.write(
            "",
            path: planPath,
            atomically: true
        )

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: ["App"], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.emptyPlan(planPath)
        )
    }

    func test_resolve_fails_whenPlanContainsOnlyComments() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        try FileHandler.shared.write(
            "\n  # comment\n  // another comment\n",
            path: planPath,
            atomically: true
        )

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.emptyPlan(planPath)
        )
    }

    func test_resolve_preservesInvalidTextEncodingError() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        fileHandler.stubExists = { $0 == planPath }
        fileHandler.stubIsFolder = { _ in false }
        fileHandler.stubReadTextFile = { _ in
            throw FileHandlerError.invalidTextEncoding(planPath)
        }

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FileHandlerError.invalidTextEncoding(planPath)
        )
    }

    func test_resolve_wrapsUnhandledReadError() throws {
        let planPath = FileHandler.shared.currentPath.appending(component: "focus.plan")
        fileHandler.stubExists = { $0 == planPath }
        fileHandler.stubIsFolder = { _ in false }
        fileHandler.stubReadTextFile = { _ in
            throw PlanReadTestError.unreadable
        }

        XCTAssertThrowsSpecific(
            try subject.resolve(sources: [], planPath: planPath.pathString),
            FocusedTargetsInputResolverError.unableToReadPlan(
                planPath,
                reason: "unreadable"
            )
        )
    }
}

private enum PlanReadTestError: Error {
    case unreadable
}
