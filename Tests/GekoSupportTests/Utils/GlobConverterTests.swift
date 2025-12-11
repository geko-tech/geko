import Foundation
import XCTest
@testable import GekoSupport
@testable import GekoSupportTesting

final class GlobConverterTests: XCTestCase {
    private var globConverter: GlobConverter!
    
    override func setUp() {
        globConverter = GlobConverter()
    }
    
    override func tearDown() {
        globConverter = nil
    }
    
    func test_one() throws {
        // given
        let glob = "LocalPods/Feature/ModuleName/Classes/**/*.{swift}"
        
        // when
        let regexStr = globConverter.toRegex(
            glob: glob,
            extended: true,
            globstar: true
        )
        let regex = try Regex(regexStr)
        
        // then
        XCTAssertEqual(
            "^LocalPods\\/Feature\\/ModuleName\\/Classes\\/((?:[^/]*(?:\\/|$))*)([^/]*)\\.(swift)$",
            regexStr
        )
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/View.swift"))
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/Util.swift"))
        XCTAssertNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/SomeData.json"))
    }
    
    func test_two() throws {
        // given
        let glob = "LocalPods/Feature/ModuleName/Classes/**/*.swift"
        
        // when
        let regexStr = globConverter.toRegex(
            glob: glob,
            extended: true,
            globstar: true
        )
        let regex = try Regex(regexStr)
        
        // then
        XCTAssertEqual(
            "^LocalPods\\/Feature\\/ModuleName\\/Classes\\/((?:[^/]*(?:\\/|$))*)([^/]*)\\.swift$",
            regexStr
        )
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/View.swift"))
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/Util.swift"))
        XCTAssertNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/SomeData.json"))
    }
    
    func test_three() throws {
        // given
        let glob = "LocalPods/Feature/ModuleName/Classes/**/*.{swift,m}"
        
        // when
        let regexStr = globConverter.toRegex(
            glob: glob,
            extended: true,
            globstar: true
        )
        let regex = try Regex(regexStr)
        
        // then
        XCTAssertEqual(
            regexStr,
            "^LocalPods\\/Feature\\/ModuleName\\/Classes\\/((?:[^/]*(?:\\/|$))*)([^/]*)\\.(swift|m)$"
        )
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/View.swift"))
        XCTAssertNotNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/Util.m"))
        XCTAssertNil(try regex.firstMatch(in: "LocalPods/Feature/ModuleName/Classes/Utils/SomeData.json"))
    }
    
    func test_four() throws {
        // given
        let glob = "Development/{Module,ModuleFoundation}/Source/**/*.swift"
        
        // when
        let regexStr = globConverter.toRegex(
            glob: glob,
            extended: true,
            globstar: true
        )
        let regex = try Regex(regexStr)
        
        // then
        XCTAssertEqual(
            regexStr,
            "^Development\\/(Module|ModuleFoundation)\\/Source\\/((?:[^/]*(?:\\/|$))*)([^/]*)\\.swift$"
        )
        XCTAssertNotNil(try regex.firstMatch(in: "Development/ModuleFoundation/Source/View.swift"))
        XCTAssertNotNil(try regex.firstMatch(in: "Development/Module/Source/View.swift"))
        XCTAssertNil(try regex.firstMatch(in: "Development/ModuleFoundation/Source/View.m"))
    }
    
    func test_five() throws {
        // given
        let glob = "Development/{Module,ModuleFoundation}/Source/**/Tests/Unit/**/*.swift"
        
        // when
        let regexStr = globConverter.toRegex(
            glob: glob,
            extended: true,
            globstar: true
        )
        let regex = try Regex(regexStr)
        
        // then
        XCTAssertEqual(
            regexStr,
            "^Development\\/(Module|ModuleFoundation)\\/Source\\/((?:[^/]*(?:\\/|$))*)Tests\\/Unit\\/((?:[^/]*(?:\\/|$))*)([^/]*)\\.swift$"
        )
        XCTAssertNil(try regex.firstMatch(in: "Development/ModuleFoundation/Source/View.swift"))
        XCTAssertNil(try regex.firstMatch(in: "Development/ModuleFoundation/Source/View.m"))
        XCTAssertNil(try regex.firstMatch(in: "Development/Module/Source/View.swift"))
        XCTAssertNotNil(try regex.firstMatch(in: "Development/ModuleFoundation/Source/Tests/Unit/UnitTest.swift"))
    }
}
