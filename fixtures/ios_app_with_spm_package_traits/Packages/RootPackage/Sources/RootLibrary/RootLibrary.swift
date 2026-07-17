#if RootFeature
    import ChildLibrary

    public let packageTraitMessage = childTraitMessage
#else
    #error("RootFeature trait must be enabled")
#endif
