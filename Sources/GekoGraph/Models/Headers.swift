import Foundation
import ProjectDescription

extension Headers {
    public var isEmpty: Bool {
        return `public`?.files.isEmpty != false
            && `private`?.files.isEmpty != false
            && project?.files.isEmpty != false
    }
}
