extension Logger.Metadata {
    public static let geko: String = "is"

    public static let successKey: String = "success"
    public static var success: Logger.Metadata {
        [geko: .string(successKey)]
    }

    public static let sectionKey: String = "section"
    public static var section: Logger.Metadata {
        [geko: .string(sectionKey)]
    }

    public static let subsectionKey: String = "subsection"
    public static var subsection: Logger.Metadata {
        [geko: .string(subsectionKey)]
    }

    public static let prettyKey: String = "pretty"
    public static var pretty: Logger.Metadata {
        [geko: .string(prettyKey)]
    }
}
