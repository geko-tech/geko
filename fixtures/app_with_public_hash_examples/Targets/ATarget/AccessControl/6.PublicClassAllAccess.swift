import Foundation

// Expected:
//
//  public class FooAllAccess {
//      public func d()
//      open func e()
//  }

public class FooAllAccess {
    private func a() {}
    internal func b() {}
    func c() {}
    public func d() {}
    open func e() {}
}
