import Foundation
import ProjectDescription

public typealias Headers = ProjectDescription.Headers

extension Headers {
    public var isEmpty: Bool {
        return `public`?.files.isEmpty != false
            && `private`?.files.isEmpty != false
            && project?.files.isEmpty != false
    }
}
