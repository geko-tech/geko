import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoCore

extension SimulatorDeviceAndRuntime {
    static func test(
        device: SimulatorDevice = .test(),
        runtime: SimulatorRuntime = .test()
    ) -> SimulatorDeviceAndRuntime {
        SimulatorDeviceAndRuntime(device: device, runtime: runtime)
    }
}
