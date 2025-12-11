import GekoAnalytics

public final class MockGekoAnalyticsStoreHandler: GekoAnalyticsStoreHandling {
    public init() {}
    
    public var invokedStoreCommand = false
    public var invokedStoreCommandParameter: GekoAnalytics.CommandEvent? = nil
    public var invokedStoreCommandParametersList = [ GekoAnalytics.CommandEvent]()
    public func store(command: GekoAnalytics.CommandEvent) throws {
        invokedStoreCommand = true
        invokedStoreCommandParameter = command
        invokedStoreCommandParametersList.append(command)
    }
    
    public var invokedStoreTargetHashes = false
    public var invokedStoreTargetHashesParameter: GekoAnalytics.TargetHashesEvent? = nil
    public var invokedStoreTargetHashesParametersList = [ GekoAnalytics.TargetHashesEvent]()
    public func store(targetHashes: GekoAnalytics.TargetHashesEvent) throws {
        invokedStoreTargetHashes = true
        invokedStoreTargetHashesParameter = targetHashes
        invokedStoreTargetHashesParametersList.append(targetHashes)
    }
}
