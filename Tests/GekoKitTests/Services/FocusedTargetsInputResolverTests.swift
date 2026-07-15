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
}
