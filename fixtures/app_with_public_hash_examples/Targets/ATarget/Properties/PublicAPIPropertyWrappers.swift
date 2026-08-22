import Foundation

// Expected:
//
//  @propertyWrapper
//  public struct PublicClampedWrapper<Value: Comparable> {
//      public var wrappedValue: Value {
//          get
//          set
//      }
//      public init(wrappedValue: Value, _ range: ClosedRange<Value>)
//  }
//
@propertyWrapper
public struct PublicClampedWrapper<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>

    public var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }

    public init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }
}

// Expected:
//
//  public struct PublicWrappedPropertiesCase {
//      @PublicClampedWrapper(0...100) public var explicitWrappedProperty: Int
//      public init()
//  }
//
public struct PublicWrappedPropertiesCase {
    @PublicClampedWrapper(0...100) public var explicitWrappedProperty: Int = 10
    @PublicClampedWrapper(0...100) private var privateWrappedProperty = 30
    public init() {}
}

// Expected: unsafe
public struct PublicWrappedInferredPropertiesCase {
    @PublicClampedWrapper(0...100) public var explicitWrappedProperty: Int = 10
    @PublicClampedWrapper(0...100) public var inferredWrappedProperty = 20
    @PublicClampedWrapper(0...100) private var privateWrappedProperty = 30
    public init() {}
}
