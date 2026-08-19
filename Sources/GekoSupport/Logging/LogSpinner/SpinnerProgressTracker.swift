import Foundation

public final class ProgressTracker<Element: Hashable> {
    
    public struct Progress {
        public let current: Element
        public let completedCount: Int
        public let totalCount: Int
        
        public var remainingCount: Int {
            max(totalCount - completedCount, 0)
        }
    }
    
    private let expectedElements: Set<Element>
    private var completedElements: Set<Element> = []
    
    // MARK: - Init
    
    public init<S: Sequence>(elements: S) where S.Element == Element {
        self.expectedElements = Set(elements)
    }
    
    // MARK: - Public
    
    public func register(_ element: Element) -> Progress? {
        guard expectedElements.contains(element) else { return nil }
        guard completedElements.insert(element).inserted else { return nil }
        
        return Progress(
            current: element,
            completedCount: completedElements.count,
            totalCount: expectedElements.count
        )
    }
}
