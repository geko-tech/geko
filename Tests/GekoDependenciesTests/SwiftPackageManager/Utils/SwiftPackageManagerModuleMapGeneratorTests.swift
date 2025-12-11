import struct ProjectDescription.AbsolutePath
import GekoSupportTesting
import GekoCoreTesting
import XCTest
import GekoSupport

@testable import GekoDependencies

class SwiftPackageManagerModuleMapGeneratorTests: GekoTestCase {
    private var subject: SwiftPackageManagerModuleMapGenerator!
    private var contentHashing: MockContentHasher!
    private var packageDirectory: AbsolutePath!
    private var publicHeadersPath: AbsolutePath!

    override func setUpWithError() throws {
        try super.setUpWithError()
        contentHashing = MockContentHasher()
        subject = SwiftPackageManagerModuleMapGenerator(contentHasher: contentHashing)
        packageDirectory = try temporaryPath()
            .appending(component: "PackageDir")
        
        publicHeadersPath = try temporaryPath()
            .appending(
                components: [
                    "Public",
                    "Headers",
                    "Path",
                ]
            )
    }

    override func tearDown() {
        contentHashing = nil
        subject = nil
        packageDirectory = nil
        publicHeadersPath = nil
        super.tearDown()
    }
    
    func test_generate_when_no_headers() throws {
        try test_generate(for: .none)
    }
    
    func test_generate_when_custom_module_map() throws {
        try test_generate(for: .custom(moduleMapPath: publicHeadersPath.appending(component: "module.modulemap"), umbrellaHeaderPath: nil))
    }
    
    func test_generate_when_umbrella_header() throws {
        try test_generate(for: .header(
            moduleMapPath: packageDirectory.appending(components: ["Derived", "Module.modulemap"]),
            umbrellaHeaderPath: publicHeadersPath.appending(component: "Module.h")
        ))
    }
    
    func test_generate_when_nested_umbrella_header() throws {
        try test_generate(for: .header(
            moduleMapPath: packageDirectory.appending(components: "Derived", "Module.modulemap"),
            umbrellaHeaderPath: publicHeadersPath.appending(components: "Module", "Module.h")
        ))
    }
    
    // MARK: - Helpers
    
    private func test_generate(for moduleMap: ModuleMap) throws {
        var writeCount = 0
        
        try FileHandler.shared.createFolder(publicHeadersPath)
        try FileHandler.shared.createFolder(packageDirectory.appending(component: "Derived"))
        switch moduleMap {
        case .none:
            break
        case let .custom(moduleMapPath, umbrellaHeaderPath):
            try FileHandler.shared.touch(moduleMapPath)
            if let umbrellaHeaderPath {
                try FileHandler.shared.createFolder(umbrellaHeaderPath.parentDirectory)
                try FileHandler.shared.touch(umbrellaHeaderPath)
            }
        case let .header(moduleMapPath, umbrellaHeaderPath):
            if !FileHandler.shared.exists(umbrellaHeaderPath.parentDirectory) {
                try FileHandler.shared.createFolder(umbrellaHeaderPath.parentDirectory)
            }
            try FileHandler.shared.touch(moduleMapPath)
            try FileHandler.shared.touch(umbrellaHeaderPath)
        case let .directory(moduleMapPath, umbrellaDirectory):
            try FileHandler.shared.touch(moduleMapPath)
            try FileHandler.shared.createFolder(umbrellaDirectory)
        }
        
        fileHandler.stubWrite = { content, path, automatically in
            writeCount += 1
            guard let expectedContent = self.expectedContent(for: moduleMap) else {
                XCTFail("FileHandler.write should not be called")
                return
            }
            XCTAssertEqual(content, expectedContent)
            XCTAssertEqual(
                path,
                self.packageDirectory.appending(components: ["Derived", "Module.modulemap"])
            )
            XCTAssertTrue(automatically)
        }
        
        contentHashing.hashStub = { hash in
            return self.expectedContent(for: moduleMap) ?? hash
        }
        
        let got = try subject.generate(
            packageDirectory: packageDirectory,
            moduleName: "Module",
            publicHeadersPath: publicHeadersPath
        )
        
        // set same module map hash for second time 
        switch moduleMap {
        case let .header(moduleMapPath: path, _), let .directory(moduleMapPath: path, _):
            contentHashing.stubHashForPath[path] = self.expectedContent(for: moduleMap) ?? ""
        case .none, .custom:
            break
        }
        
        // generate a 2nd time to validate that we dont write content that is already on disk
        _ = try subject.generate(
            packageDirectory: packageDirectory,
            moduleName: "Module",
            publicHeadersPath: publicHeadersPath
        )
        
        XCTAssertEqual(got, moduleMap)
        switch moduleMap {
        case .none, .custom:
            XCTAssertEqual(writeCount, 0)
        case .directory, .header:
            XCTAssertEqual(writeCount, 1)
        }
    }
    
    private func expectedContent(for moduleMap: ModuleMap) -> String? {
        let expectedContent: String
        switch moduleMap {
        case .none, .custom:
            return nil
        case let .header(_, umbrellaHeaderPath):
            if umbrellaHeaderPath.parentDirectory.basename == "Module" {
                expectedContent = """
                framework module Module {
                  umbrella header "\(umbrellaHeaderPath.pathString)"

                  export *
                  module * { export * }
                }
                """
            } else {
                expectedContent = """
                framework module Module {
                  umbrella header "\(umbrellaHeaderPath.pathString)"

                  export *
                  module * { export * }
                }
                """
            }
        case let .directory(_, umbrellaDirectory):
            expectedContent = """
            module Module {
                umbrella "\(umbrellaDirectory.pathString)"
                export *
            }

            """
        }
        return expectedContent
    }
}
