import Foundation

// Expected:
//
//  public struct PublicCrossFileExtensionCase {
//      public let value: Int
//      public init(value: Int)
//  }
//
public struct PublicCrossFileExtensionCase {
    public let value: Int
    public init(value: Int) { self.value = value }
}

// Expected:
//
//  public struct PublicCrossFileConformanceCase {
//      public init()
//  }
//
public struct PublicCrossFileConformanceCase {
    public init() {}
}

// Expected: ignore
struct InternalCrossFileExtensionCase {
    let value: Int
}

// Expected:
//
//  public struct PublicGenericExtensionCase<Element> {
//      public let element: Element
//      public init(element: Element)
//  }
public struct PublicGenericExtensionCase<Element> {
    public let element: Element
    public init(element: Element) { self.element = element }
}
