import MultiPodInterfaces

public final class MultiPodFileMock: MultiPodInterfaceFile {
    var stubbedHelloResult: String = ""
    public func hello() -> String {
        return stubbedHelloResult
    }
}
