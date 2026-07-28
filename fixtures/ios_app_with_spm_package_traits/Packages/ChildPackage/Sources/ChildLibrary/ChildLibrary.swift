#if ChildFeature
    public let childTraitMessage = "SwiftPM package traits"
#else
    #error("ChildFeature trait must be enabled")
#endif
