import Foundation


@propertyWrapper
public struct Wrapper<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

public struct PropertyAPICases {
    private var mutable = 0

    // 1. Stored let
    public let storedLet: Int = 1

    // 2. Stored var
    public var storedVar: Int = 2

    // 3. Computed, getter only
    public var getterOnlyProperty: Int { 9 }

    // 4. Computed, get + set
    public var getterSetterProperty: Int {
        get { mutable }
        set { mutable = newValue }
    }

    // 5. Restricted setter
    public private(set) var privateSetterProperty: Int = 3

    // 6. Internal setter
    public internal(set) var internalSetterProperty: Int = 4

    // 7. Property observers
    public var observedProperty: Int = 5 {
        willSet { print(newValue) }
        didSet { print(oldValue) }
    }

    // 8. Lazy property
    public lazy var lazyProperty: Int = 6

    // 9. Static stored property
    public static let staticLet: Int = 7

    // 10. Static computed property
    public static var staticComputed: Int { 8 }

    // 11. Explicit getter
    public var explicitGet: Int {
        get { 9 }
    }

    // 12. Getter reading private state
    public var readOnlyViaPrivateSet: Int {
        get { mutable }
    }

    // 13. Property wrapper
    @Wrapper public var wrapped: Int = 10

    public init() {}
}

open class PropertyClassCases {
    private var mutable = 0

    // 14. Class computed property
    public class var classComputed: Int { 11 }

    // 15. Get + set
    public var getSet: Int {
        get { mutable }
        set { mutable = newValue }
    }

    // 16. Open computed property
    open var openComputed: Int { 12 }

    public required init() {}
}

// 17. Inlinable computed property
public struct InlinablePropertyCases {
    @inlinable public var computed: Int { 42 }
}



public struct PublicAPIBalancedCases {

    // 1. Простой default argument
    public init(valueA: Int = 1) {}

    // 2. Вложенный вызов функции
    public init(valueB: Int = max(1, 2)) {}

    // 3. Замыкание в default argument
    public init(valueC: Int = { 1 }()) {}

    // 4. Замыкание с вложенным вызовом
    public init(valueD: Int = { max(1, 2) }()) {}

    // 5. Вложенные замыкания
    public init(valueE: Int = { { 1 }() }()) {}

    // 6. Замыкание с несколькими инструкциями
    public init(valueF: Int = {
        let x = 1
        return x
    }()) {}

    // 7. Строка со скобками внутри замыкания
    public init(valueG: Int = {
        let text = "hello } )"
        return text.count
    }()) {}

    // 8. Комментарий со скобками внутри замыкания
    public init(valueH: Int = {
        /* } ) */
        return 1
    }()) {}

    // 9. Array + trailing closure
    public init(
        values: [Int] = [1, 2, 3].map { $0 * 2 }
    ) {}

    // 10. Несколько параметров
    public init(
        first: Int = max(1, 2),
        second: Bool = true
    ) {}

    // 11. Метод с замыканием в default argument
    public func method(value: Int = { 4 }()) {}

    // 12. Метод после сложного init
    public func next() {}
}

// 13. Публичные свойства с инициализаторами
public struct PublicAPIPropertyCases {

    public let value: Int = { 1 }()
    public let other: Int = 4

    public init() {}
}

// 14. Глобальная функция с замыканием
public func globalDefault(value: Int = { 3 }()) {}

// 15. Строка с фигурной скобкой
public func stringDefault(
    text: String = "hello } )"
) {}

// 16. Массив
public func arrayDefault(
    values: [Int] = [1, 2]
) {}

// 17. Вложенные вызовы
public func nestedDefault(
    value: Int = max(1, min(2, 3))
) {}

// 18. Сложный default argument из нашей фикстуры
public func complexDefault(
    values: [Int] = Array(1...3).map { $0 * 2 }
) {}

// Expected: ignore
struct InternalStructCase {
    var value: Int
}

// Expected: ignore
private struct PrivateStructCase {
    var value: Int
}

// Expected: public struct PublicEmptyStructCase {}
public struct PublicEmptyStructCase {}
// Expected: public enum PublicEmptyEnumCase {}
public enum PublicEmptyEnumCase {}
// Expected: public actor PublicActorCase {}
public actor PublicActorCase {}
// Expected: open class OpenClassCase {}
open class OpenClassCase {}

// Expected:
//
//  public struct PublicMixedAccessContainerCase {
//      public let publicProperty: Int
//      public init(publicProperty: Int = 3)
//      public func publicMethod()
//  }
//
public struct PublicMixedAccessContainerCase {
    private let privateProperty = 1
    let internalProperty = 2
    public let publicProperty: Int

    public init(publicProperty: Int = 3) {
        self.publicProperty = publicProperty
    }

    private func privateMethod() {}
    func internalMethod() {}
    public func publicMethod() {}
}

// Expected: public struct PublicPrivateNestedOuterCase {}
public struct PublicPrivateNestedOuterCase {
    private struct PrivateNestedCase {
        func publicLookingMethod() {}
    }
}
