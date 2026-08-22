import Foundation

// Expected:
//
//  public struct FooNested {
//        public struct Bar {
//            public func baz()
//      }
//  }

public struct FooNested {
    public struct Bar {
        public func baz() {}
    }
}
