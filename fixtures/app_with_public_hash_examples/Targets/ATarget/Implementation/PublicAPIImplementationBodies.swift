import Foundation

// Expected: public func publicOrdinaryBodyFunction() -> Int
public func publicOrdinaryBodyFunction() -> Int { 101 }

// Expected:
//
//  @inlinable
//  public func publicInlinableBodyFunction() -> Int { 202 }
//
@inlinable
public func publicInlinableBodyFunction() -> Int { 202 }

// Expected:
//
//  @_alwaysEmitIntoClient
//  public func publicAlwaysEmitBodyFunction() -> Int { 303 }
//
@_alwaysEmitIntoClient
public func publicAlwaysEmitBodyFunction() -> Int { 303 }

// Expected:
//
//  @_transparent
//  public func publicTransparentBodyFunction() -> Int { 404 }
//
@_transparent
public func publicTransparentBodyFunction() -> Int { 404 }
