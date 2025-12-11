import CallKit
import InterimSinglePod

final class CallDirectoryHandler: CXCallDirectoryProvider {

    override init() {
        super.init()
    }

    // MARK: - CXCallDirectoryProvider

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        super.beginRequest(with: context)

    }
}
