import Foundation

// Expected:
//
// public struct FooInternalNested {}

public struct FooInternalNested {
    struct Bar {
        public func baz() {}
    }
}
