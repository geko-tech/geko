import Foundation

// Expected:
//
//  @_spi(Internal)
//  public func spiInternalFunction() -> Int
//
@_spi(Internal)
public func spiInternalFunction() -> Int { 2 }

// Expected:
//
//  @_spi(Internal)
//  public let spiProperty: Int
//
@_spi(Internal)
public let spiProperty: Int = 3
