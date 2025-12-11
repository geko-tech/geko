import Foundation

protocol IDIContext: AnyObject {
    typealias Instance = AnyObject
    
    var lock: NSLocking { get }
    var singletons: [ServiceKey: Instance] { get set }
    var objectGraphStorage: [ServiceKey: Instance] { get set }
    
    func incrementObjectGraphResolutionDepth()
    func decrementObjectGraphResolutionDepth()
}

final class DIContext: IDIContext {
    
    static let shared = DIContext()
    let lock: NSLocking = NSRecursiveLock()
    
    var singletons: [ServiceKey: Instance] = [:]
    var objectGraphStorage: [ServiceKey: Instance] = [:]
    
    // MARK: - Graph resolving
    
    private var objectGraphResolutionDepth = 0
    
    func incrementObjectGraphResolutionDepth() {
        objectGraphResolutionDepth += 1
    }
    
    func decrementObjectGraphResolutionDepth() {
        objectGraphResolutionDepth -= 1
        if objectGraphResolutionDepth == 0 {
            objectGraphStorage.removeAll()
        }
    }
    
    // MARK: - Initializer
    
    private init() {}
}

