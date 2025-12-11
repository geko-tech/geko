open class ManualDIAssembly {
    
    public enum Scope {
        case singleton
        case objectGraph
        case prototype
    }
    
    // Dependencies
    private let context = DIContext.shared
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public

    @available(*, deprecated, message: "Use method `resolve` without `key` parameter")
    public func resolve<T>(key: Any.Type,
                           name: String? = nil,
                           scope: Scope,
                           factory: () -> T) -> T {
        switch scope {
        case .singleton:
            context.lock.lock(); defer { context.lock.unlock() }
            
            let registryKey = ServiceKey(serviceType: key, name: name)
            return resolveSingleton(registryKey, factory: factory)
        case .objectGraph:
            context.lock.lock(); defer { context.lock.unlock() }
            
            let registryKey = ServiceKey(serviceType: key, name: name)
            return resolveGraph(registryKey, factory: factory)
        case .prototype:
            return factory()
        }
    }

    public func resolve<T>(name: String? = nil,
                           scope: Scope,
                           factory: () -> T) -> T {
        let key = T.self
        switch scope {
        case .singleton:
            context.lock.lock(); defer { context.lock.unlock() }

            let registryKey = ServiceKey(serviceType: key, name: name)
            return resolveSingleton(registryKey, factory: factory)
        case .objectGraph:
            context.lock.lock(); defer { context.lock.unlock() }

            let registryKey = ServiceKey(serviceType: key, name: name)
            return resolveGraph(registryKey, factory: factory)
        case .prototype:
            return factory()
        }
    }

    // MARK: - Private
    
    // MARK: - ObjectGraph
    
    private func resolveGraph<T>(_ key: ServiceKey, factory: () -> T) -> T {
        if let obj = context.objectGraphStorage[key], let persistedInstance = obj as? T {
            return persistedInstance
        } else {
            context.incrementObjectGraphResolutionDepth()
            defer {
                context.decrementObjectGraphResolutionDepth()
            }
            
            let instance = factory()
            context.objectGraphStorage[key] = instance as AnyObject
            return instance
        }
    }
    
    // MARK: - Singleton
    
    private func resolveSingleton<T>(_ key: ServiceKey, factory: () -> T) -> T {
        if let obj = context.singletons[key], let instance = obj as? T {
            return instance
        } else {
            let instance = factory()
            context.singletons[key] = instance as AnyObject
            return instance
        }
    }
}

