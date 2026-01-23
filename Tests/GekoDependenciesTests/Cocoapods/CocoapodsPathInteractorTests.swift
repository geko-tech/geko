import Foundation
@testable import GekoDependencies
import GekoDependenciesTesting
import GekoGraph
import GekoLoader
import GekoSupport
import GekoSupportTesting
import GekoCoreTesting
import ProjectDescription
import XCTest

extension CocoapodsPathInteractorError: @retroactive Equatable {
    public static func == (lhs: CocoapodsPathInteractorError, rhs: CocoapodsPathInteractorError) -> Bool {
        switch (lhs, rhs) {
        case let (.specNotFound(lName, lPath), .specNotFound(rName, rPath)):
            return lName == rName && lPath == rPath
        case let (.specNameDiffers(lFileName, lSpecName), .specNameDiffers(rFileName, rSpecName)):
            return lFileName == rFileName && lSpecName == rSpecName
        default:
            return false
        }
    }
}

final class CocoapodsPathInteractorTests: GekoUnitTestCase {
    private var locationProviderStub: StubCocoapodsLocationProvider!
    private var podspecConverterStub: StubCocoapodsPodspecConverter!

    private var path: AbsolutePath!
    private var manifestDirectory: AbsolutePath!
    private var rootDirectoryLocator: MockRootDirectoryLocator!
    private var generatorPaths: GeneratorPaths!

    override func setUp() {
        super.setUp()

        locationProviderStub = StubCocoapodsLocationProvider()
        podspecConverterStub = StubCocoapodsPodspecConverter()

        path = try! temporaryPath()
        manifestDirectory = path.appending(component: Constants.gekoDirectoryName)
        rootDirectoryLocator = MockRootDirectoryLocator()
        rootDirectoryLocator.locateStub = path
        generatorPaths = GeneratorPaths(
            manifestDirectory: manifestDirectory,
            rootDirectoryLocator: rootDirectoryLocator
        )
    }

    override func tearDown() {
        locationProviderStub = nil
        podspecConverterStub = nil

        path = nil
        manifestDirectory = nil
        rootDirectoryLocator = nil
        generatorPaths = nil

        super.tearDown()
    }

    // MARK: - Tests

    func testObtainSpecs() throws {
        // arrange
        try createFiles(["Utils.podspec", "Atomic.podspec.json"])
        let commandStub = "some_command"
        let firstPodspecData = try XCTUnwrap(firstPodspec.data(using: .utf8))
        let secondPodspecData = try XCTUnwrap(secondPodspec.data(using: .utf8))

        let config = Config.default
        let pathConfigsStub: [CocoapodsPathInteractor.PathConfig] = [
            .init(name: "Utils", path: .relativeToRoot(".")),
            .init(name: "Atomic", path: .relativeToRoot("."))
        ]
        let subject = CocoapodsPathInteractor(
            path: path,
            generatorPaths: generatorPaths,
            manifestConfig: config,
            pathConfigs: pathConfigsStub,
            fileHandler: fileHandler,
            cocoapodsLocationProvider: locationProviderStub,
            podspecConverter: podspecConverterStub
        )

        locationProviderStub.shellCommandStub = { _ in
            return [commandStub]
        }

        var correctShellCommandPassed = false
        podspecConverterStub.convertStub = { paths, shellCommand in
            correctShellCommandPassed = shellCommand == [commandStub]
            var output: [(String, Data)] = []
            for (path, data) in zip(paths, [firstPodspecData, secondPodspecData]) {
                output.append((path, data))
            }
            return output
        }

        // act
        try subject.obtainSpecs()
        let (utils, utilsSource) = subject.spec(for: "Utils")
        let (atomic, atomicSource) = subject.spec(for: "Atomic")

        // assert
        XCTAssertTrue(correctShellCommandPassed)

        XCTAssertEqual(utils.name, "Utils")
        XCTAssertEqual(atomic.name, "Atomic")

        if case .path(let name) = utilsSource {
            XCTAssertEqual(name, ".")
        } else {
            XCTFail("should be .path")
        }

        if case .path(let name) = atomicSource {
            XCTAssertEqual(name, ".")
        } else {
            XCTFail("should be .path")
        }
    }

    func testObtainSpecs_pathsAreNotValid_shouldThrowError() throws {
        // arrange
        try createFiles(["Utils.podspec", "Atomic.podspec.json"])
        let commandStub = "some_command"
        let firstPodspecData = try XCTUnwrap(firstPodspec.data(using: .utf8))
        let secondPodspecData = try XCTUnwrap(secondPodspec.data(using: .utf8))

        let config = Config.default
        let pathConfigsStub: [CocoapodsPathInteractor.PathConfig] = [
            .init(name: "Utils", path: "../some_folder"),
            .init(name: "Atomic", path: "../some_another_folder")
        ]
        let subject = CocoapodsPathInteractor(
            path: path,
            generatorPaths: generatorPaths,
            manifestConfig: config,
            pathConfigs: pathConfigsStub,
            fileHandler: fileHandler,
            cocoapodsLocationProvider: locationProviderStub,
            podspecConverter: podspecConverterStub
        )

        locationProviderStub.shellCommandStub = { _ in
            return [commandStub]
        }

        podspecConverterStub.convertStub = { paths, shellCommand in
            var output: [(String, Data)] = []
            for (path, data) in zip(paths, [firstPodspecData, secondPodspecData]) {
                output.append((path, data))
            }
            return output
        }

        // act
        XCTAssertThrowsSpecific(
            try subject.obtainSpecs(),
            CocoapodsPathInteractorError.specNotFound(
                name: "Utils",
                path: try temporaryPath().appending(component: "Geko").appending(pathConfigsStub[0].path)
            )
        )
    }

    // MARK: - Private

    private let firstPodspec: String = """
    {
      "name": "Utils",
      "version": "3.7.1",
      "platforms": {
        "ios": "15.0"
      },
      "source": {
        "git": "https://github.com/my-org/utils.git",
        "tag": "Utils/3.7.1"
      },
      "source_files": "Development/Utils/Sources/**/*.{swift,h,m}",
    }
    """

    private let secondPodspec: String = """
    {
      "name": "Atomic",
      "version": "3.7.1",
      "platforms": {
        "ios": "15.0"
      },
      "source": {
        "git": "https://github.com/my-org/utils.git",
        "tag": "utils/3.7.1"
      },
      "source_files": "Development/Uitls/Sources/**/*.{swift,h,m}",
    }
    """
}
