import Foundation

// Expected:
//
//  public actor PublicWorkerActorCase {
//      public init()
//      public func actorMethod() -> Int
//      public func asyncActorMethod() async -> Int
//      public nonisolated func nonisolatedActorMethod() -> Int
//      nonisolated public var nonisolatedActorLabel: String { get }
//  }
//
public actor PublicWorkerActorCase {
    public init() {}
    public func actorMethod() -> Int { 1 }
    public func asyncActorMethod() async -> Int { 2 }
    public nonisolated func nonisolatedActorMethod() -> Int { 3 }
    public nonisolated var nonisolatedActorLabel: String { "nonisolated" }
}

// Expected:
//
// public func publicIsolatedActorParameterFunction(actor: isolated PublicWorkerActorCase) -> Int
//
public func publicIsolatedActorParameterFunction(actor: isolated PublicWorkerActorCase) -> Int {
    actor.actorMethod()
}

// Expected:
//
//  @MainActor
//  public struct PublicMainActorTypeCase {
//      public init()
//      public func mainActorMethod()
//  }
//
@MainActor
public struct PublicMainActorTypeCase {
    public init() {}
    public func mainActorMethod() {}
}

// Expected:
//
//  @MainActor
//  public func publicMainActorFunction()
//
@MainActor
public func publicMainActorFunction() {}
