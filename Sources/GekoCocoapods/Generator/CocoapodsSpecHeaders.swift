import ProjectDescription

public struct CocoapodsSpecHeaders {
    public var publicHeaders: [AbsolutePath]
    public var privateHeaders: [AbsolutePath]
    public var projectHeaders: [AbsolutePath]
    public var mappingsDir: String?
    public var umbrellaHeaderContent: String
    public var umbrellaHeaderPath: AbsolutePath?
}
