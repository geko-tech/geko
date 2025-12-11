import Foundation
import GekoSupport

public final class StubCocoapodsPodspecConverter: CocoapodsPodspecConverting {

    public init() {}

    public var convertStub: (([String], [String]) throws -> [(podspecPath: String, podspecData: Data)])?

    public func convert(paths: [String], shellCommand: [String]) throws -> [(podspecPath: String, podspecData: Data)] {
        try convertStub?(paths, shellCommand) ?? []
    }
}
