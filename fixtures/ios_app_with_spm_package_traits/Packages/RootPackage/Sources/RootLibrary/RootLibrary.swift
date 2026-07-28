#if RootFeature
    import ChildLibrary

    public let packageTraitMessage = childTraitMessage
#else
    #error("RootFeature trait must be enabled")
#endif

#if !ROOT_TRAIT_SETTING
    #error("Trait-conditioned Swift setting must be enabled")
#endif
