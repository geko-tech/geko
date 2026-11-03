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
    
    // MARK: - Access control
    
    func test_public_empty_struct() throws {
        // Given
        let source = """
        public struct FooPublicEmpty {}    
        """
        
        let expected = """
        public struct FooPublicEmpty {
        }
        """
        
        // When
        let result = try parse(source)
        
        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_empty_struct_with_import() throws {
        // Given
        let source = """
        import Foundation

        public struct FooPublicEmpty {}    
        """
        
        let expected = """
        public struct FooPublicEmpty {
        }
        """
        
        // When
        let result = try parse(source)
        
        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_open_empty_class() throws {
        // Given
        let source = """
        import Foundation

        open class FooOpenEmpty {}
        """

        let expected = """
        open class FooOpenEmpty {
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_struct_with_members() throws {
        // Given
        let source = """
        public struct FooPublicWithMembers {
            let internalValue: Int
            public let publicValue: Int
        }
        """

        let expected = """
        public struct FooPublicWithMembers {
            public let publicValue : Int
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_internal_property_does_not_affect_public_api() throws {
        let original = """
        public struct Foo {
            let internalValue: Int
            public let publicValue: Int
        }
        """

        let modified = """
        public struct Foo {
            let internalValue: String
            public let publicValue: Int
        }
        """

        XCTAssertEqual(try parse(original), try parse(modified))
    }
    
    func test_public_property_type_affects_public_api() throws {
        let original = """
        public struct Foo {
            public let value: Int
        }
        """

        let modified = """
        public struct Foo {
            public let value: String
        }
        """

        XCTAssertNotEqual(try parse(original), try parse(modified))
    }
    
    func test_public_class_all_access_levels() throws {
        // Given
        let source = """
        public class FooAllAccess {
            private func a() {}
            internal func b() {}
            func c() {}
            public func d() {}
            open func e() {}
        }
        """

        let expected = """
        public class FooAllAccess {
            public func d ( )
            open func e ( )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_empty_enum() throws {
        // Given
        let source = """
        public enum PublicEmptyEnumCase {}
        """

        let expected = """
        public enum PublicEmptyEnumCase {
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_empty_actor() throws {
        // Given
        let source = """
        public actor PublicActorCase {}
        """

        let expected = """
        public actor PublicActorCase {
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_struct_with_private_nested_struct() throws {
        // Given
        let source = """
        public struct PublicPrivateNestedOuterCase {
            private struct PrivateNestedCase {
                func publicLookingMethod() {}
            }
        }
        """

        let expected = """
        public struct PublicPrivateNestedOuterCase {
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_private_properties_with_initializers() throws {
        // Given
        let source = """
        public struct Foo {
            private let privateProperty = 1
            let internalProperty = 2
            public let publicProperty: Int
        }
        """

        let expected = """
        public struct Foo {
            public let publicProperty : Int
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_property_with_inferred_type_returns_unsafe() throws {
        // Given
        let source = """
        public struct Foo {
            public let value = 1
        }
        """

        let path = try createFiles(
            ["InferredPublicProperty.swift"],
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
    
    func test_public_property_with_explicit_type_and_initializer() throws {
        // Given
        let source = """
        public class Foo {
            public let value: Int = 1
        }
        """

        let expected = """
        public class Foo {
            public let value : Int
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_default_argument() throws {
        // Given
        let source = """
        public struct Foo {
            public let value: Int

            public init(value: Int = 3) {
                self.value = value
            }
        }
        """

        let expected = """
        public struct Foo {
            public let value : Int
            public init ( value : Int = 3 )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_nested_default_argument() throws {
        // Given
        let source = """
        public struct Foo {
            public init(value: Int = max(1, 2)) {}
        }
        """

        let expected = """
        public struct Foo {
            public init ( value : Int = max ( 1 , 2 ) )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_multiple_nested_defaults() throws {
        // Given
        let source = """
        public struct Foo {
            public init(
                first: Int = max(1, 2),
                second: Int = min(3, 4)
            ) {}
        }
        """

        let expected = """
        public struct Foo {
            public init ( first : Int = max ( 1 , 2 ) , second : Int = min ( 3 , 4 ) )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_array_default() throws {
        // Given
        let source = """
        public struct Foo {
            public init(values: [Int] = [1, 2, 3]) {}
        }
        """

        let expected = """
        public struct Foo {
            public init ( values : [ Int ] = [ 1 , 2 , 3 ] )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_closure_default_simple() throws {
        // Given
        let source = """
        public struct Foo {
            public init(value: Int = { 1 }()) {}
        }
        """

        let expected = """
        public struct Foo {
            public init ( value : Int = { 1 } ( ) )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_initializer_with_closure_default() throws {
        // Given
        let source = """
        public struct Foo {
            public init(transform: (Int) -> Int = { value in value + 1 }) {}
        }
        """

        let expected = """
        public struct Foo {
            public init ( transform : ( Int ) -> Int = { value in value + 1 } )
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_computed_property_getter_only() throws {
        // Given
        let source = """
        public struct Foo {
            public var value: Int { 9 }
        }
        """

        let expected = """
        public struct Foo {
            public var value : Int {
                get
            }
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_public_computed_property_getter_setter() throws {
        // Given
        let source = """
        public struct Foo {
            private var storage: Int = 0

            public var value: Int {
                get { storage }
                set { storage = newValue }
            }
        }
        """

        let expected = """
        public struct Foo {
            public var value : Int {
                get
                set
            }
        }
        """

        // When
        let result = try parse(source)

        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_computed_property_getter_body_does_not_affect_public_api() throws {
        // Given
        let original = """
        public struct Foo {
            public var value: Int { 9 }
        }
        """

        let modified = """
        public struct Foo {
            public var value: Int { 42 }
        }
        """

        // When
        let originalAPI = try parse(original)
        let modifiedAPI = try parse(modified)

        // Then
        XCTAssertEqual(originalAPI, modifiedAPI)
    }
    
    func test_public_computed_property_setter_affects_public_api() throws {
        let getterOnly = """
        public struct Foo {
            public var value: Int { 9 }
        }
        """

        let getterSetter = """
        public struct Foo {
            private var storage: Int = 0

            public var value: Int {
                get { storage }
                set { storage = newValue }
            }
        }
        """

        XCTAssertNotEqual(try parse(getterOnly), try parse(getterSetter))
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
