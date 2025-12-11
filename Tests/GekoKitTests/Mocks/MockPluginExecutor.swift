import Foundation
import GekoPlugin
@testable import GekoKit

public final class MockPluginExecutor: IPluginExecutor {
    public init() {}
    
    public func execute(arguments: [String]) throws {}
}

