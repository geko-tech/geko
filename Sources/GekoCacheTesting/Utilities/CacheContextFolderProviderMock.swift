import Foundation
import GekoCache

public final class CacheContextFolderProviderMock: CacheContextFolderProviding {
    public var stubContextFolderName: String = ""
    public func contextFolderName() -> String {
        stubContextFolderName
    }
}
