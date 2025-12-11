import AnyCodable
import Foundation

enum ProjectGenerationFinishedType: String {
    case failure
    case cancelled
    case success
}

protocol IProjectGenerationAnalytics {
    func fetchDidFinished(generationFinishedType: ProjectGenerationFinishedType, duration: String)
    func generationDidFinished(generationFinishedType: ProjectGenerationFinishedType, duration: String)
}

final class ProjectGenerationAnalytics: IProjectGenerationAnalytics {
    
    private let baseAnalytics: BaseAnalytics
    
    init(baseAnalytics: BaseAnalytics) {
        self.baseAnalytics = baseAnalytics
    }
    
    func fetchDidFinished(generationFinishedType: ProjectGenerationFinishedType, duration: String) {
        baseAnalytics.send(analytics: LogAnalytics(name: "fetchDidFinished", info: [
            "fetchFinishedType": AnyCodable(generationFinishedType.rawValue),
            "duration": AnyCodable(duration)
        ]))
    }
    
    func generationDidFinished(generationFinishedType: ProjectGenerationFinishedType, duration: String) {
        baseAnalytics.send(analytics: LogAnalytics(name: "generationDidFinished", info: [
            "generationFinishedType": AnyCodable(generationFinishedType.rawValue),
            "duration": AnyCodable(duration)
        ]))
    }
} 
