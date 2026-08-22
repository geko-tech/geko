import Foundation

// Expected:
//
//  public struct ADeepNesting {
//      public enum BDeepNesting {
//          public struct CDeepNesting {
//              public func foo()
//          }
//      }
//  }

public struct ADeepNesting {
    public enum BDeepNesting {
        public struct CDeepNesting {
            public func foo() {}
        }
    }
}
