import struct ProjectDescription.AbsolutePath
import GekoSupport

final class PluginTestService {
    func run(
        path: String?,
        configuration: PluginCommand.PackageConfiguration,
        buildTests: Bool,
        testProducts: [String]
    ) throws {
        guard try isPackageExists(at: path) else {
            logger.notice("The plugin does not have a Package.swift, there is nothing to test.", metadata: .success)
            return
        }
        var testCommand = [
            "swift", "test",
            "--configuration", configuration.rawValue,
        ]
        if let path {
            testCommand += [
                "--package-path",
                try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath).pathString,
            ]
        }
        if buildTests {
            testCommand.append(
                "--build-tests"
            )
        }
        for testProduct in testProducts {
            testCommand += [
                "--test-product", testProduct,
            ]
        }
        try System.shared.runAndPrint(testCommand)
    }
    
    private func isPackageExists(at path: String?) throws -> Bool {
        let path = try self.path(path)
        let packagePath = path.appending(component: "Package.swift")
        return FileHandler.shared.exists(packagePath)
    }
    
    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }
}
