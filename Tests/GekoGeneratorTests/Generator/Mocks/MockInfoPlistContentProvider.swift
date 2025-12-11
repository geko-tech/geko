import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
@testable import GekoGenerator

final class MockInfoPlistContentProvider: InfoPlistContentProviding {
    var contentArgs: [(project: Project, target: Target, extendedWith: [String: Plist.Value])] = []
    var contentStub: [String: Any]?

    func content(project: Project, target: Target, extendedWith: [String: Plist.Value]) -> [String: Any]? {
        contentArgs.append((project: project, target: target, extendedWith: extendedWith))
        return contentStub ?? [:]
    }
}
