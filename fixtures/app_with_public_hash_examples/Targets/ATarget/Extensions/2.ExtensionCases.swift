import Foundation

// Expected:
//
//  extension PublicCrossFileExtensionCase {
//      public func publicExtensionMethod() -> Int
//  }
//
extension PublicCrossFileExtensionCase {
    public func publicExtensionMethod() -> Int { value }
    func internalExtensionMethod() {}
}

// Expected:
//
//  extension PublicCrossFileConformanceCase: PublicCrossFileProtocol {
//      public func crossFileRequirement() -> String
//  }
//
extension PublicCrossFileConformanceCase: PublicCrossFileProtocol {
    public func crossFileRequirement() -> String { "conformance" }
}

// Expected:
//
//  extension PublicGenericExtensionCase where Element: Equatable {
//      public func equals(_ other: Element) -> Bool
//  }
//
extension PublicGenericExtensionCase where Element: Equatable {
    public func equals(_ other: Element) -> Bool { element == other }
}

// Expected: ignore
extension InternalCrossFileExtensionCase {
    func internalOnlyExtensionMethod() -> Int { value }
}

// Expected: ignore
private extension PublicCrossFileExtensionCase {
    func privateExtensionMethod() {}
}
