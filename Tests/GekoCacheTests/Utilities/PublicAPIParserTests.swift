import struct ProjectDescription.AbsolutePath
import GekoSupport
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class PublicAPIParserTests: GekoUnitTestCase {
    var subject: PublicAPIParser!
    
    override func setUp() {
        super.setUp()
        subject = PublicAPIParser()
    }
    
    override func tearDown() {
        super.tearDown()
        subject = nil
    }
    
    
    func test_public_class_old() throws {
        // Given
        let source = """
        public class TestClass {
            init() {
            }

            private func func1() {}

            public func func2() {}
        }
        """
        
        let expected = """
        public class TestClass {
            public func func2 ( )
        }
        """
        // When
        let result = try parse(source)
        
        // Then
        XCTAssertEqual(result, expected)
        
    }
    
    func test_nested_public_class_old() throws {
        let source = """
        public class TestClass {
            init() {
            }

            private func func1() {
                print(123)
            }

            public class NestedClass {
                public init() {
                    printf()
                }

                public func func2() {}
            }
        }
        """

        let expected = """
        public class TestClass {
            public class NestedClass {
                public init ( )
                public func func2 ( )
            }
        }
        """

        let result = try parse(source)

        XCTAssertEqual(result, expected)
    }
    
    func test_unsupported_syntax_returns_unsafe() throws {
        // Given
        let source = """
        public func calculate(_ value: Int = 10 / 2) {}
        """

        let path = try createFiles(
            ["Unsupported.swift"],
            content: source
        ).first!

        // When
        let result = try subject.parse(filePath: path)

        // Then
        XCTAssertEqual(
            result,
            .unsafe(reason: "Unsupported Swift syntax.")
        )
    }
    
    private func parse(_ source: String) throws -> String {
        let path = try createFiles(
            ["Example.swift"],
            content: source
        ).first!

        let result = try subject.parse(filePath: path)

        guard case let .safe(interface) = result else {
            XCTFail("Expected safe result, got \(result)")
            return ""
        }

        return interface.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
