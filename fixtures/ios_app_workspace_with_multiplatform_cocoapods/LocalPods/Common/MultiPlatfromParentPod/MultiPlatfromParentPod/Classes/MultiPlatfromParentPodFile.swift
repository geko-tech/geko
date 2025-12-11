import Foundation

public class MultiPlatfromParentPodFile {
    public init() {}

    public func hello() -> String {
        print(TestLibraryLogger().logMessage())
        return "MultiPlatfromParentPodFile.hello()"
    }
}
