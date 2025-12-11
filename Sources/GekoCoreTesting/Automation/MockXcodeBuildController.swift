import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport
@testable import GekoSupportTesting

final class MockXcodeBuildController: XcodeBuildControlling {
    var buildStub: ((
        XcodeBuildTarget,
        String,
        XcodeBuildDestination?,
        Bool,
        AbsolutePath?,
        Bool,
        [XcodeBuildArgument]
    ) -> [SystemEvent<XcodeBuildOutput>])?

    func build(
        _: GekoCore.XcodeBuildTarget,
        scheme _: String,
        destination _: GekoCore.XcodeBuildDestination?,
        rosetta _: Bool,
        derivedDataPath _: AbsolutePath?,
        clean _: Bool,
        arguments _: [GekoCore.XcodeBuildArgument]
    ) throws {}

    var testStub: (
        (
            XcodeBuildTarget,
            String,
            Bool,
            XcodeBuildDestination,
            Bool,
            AbsolutePath?,
            AbsolutePath?,
            [XcodeBuildArgument],
            Int,
            [TestIdentifier],
            [TestIdentifier],
            TestPlanConfiguration?
        )
            -> Void
    )?
    var testErrorStub: Error?
    func test(
        _ target: GekoCore.XcodeBuildTarget,
        scheme: String,
        clean: Bool,
        destination: GekoCore.XcodeBuildDestination,
        rosetta: Bool,
        derivedDataPath: AbsolutePath?,
        resultBundlePath: AbsolutePath?,
        arguments: [GekoCore.XcodeBuildArgument],
        retryCount: Int,
        testTargets: [GekoCore.TestIdentifier],
        skipTestTargets: [GekoCore.TestIdentifier],
        testPlanConfiguration: GekoCore.TestPlanConfiguration?
    ) throws {
        if let testStub {
            testStub(
                target,
                scheme,
                clean,
                destination,
                rosetta,
                derivedDataPath,
                resultBundlePath,
                arguments,
                retryCount,
                testTargets,
                skipTestTargets,
                testPlanConfiguration
            )
            if let testErrorStub {
                throw testErrorStub
            }
        } else {
            throw TestError(
                "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to test"
            )
        }
    }

    func archive(
        _: GekoCore.XcodeBuildTarget,
        scheme _: String,
        clean _: Bool,
        archivePath _: AbsolutePath,
        arguments _: [GekoCore.XcodeBuildArgument],
        derivedDataPath _: AbsolutePath?
    ) throws {}

    func createXCFramework(
        arguments _: [GekoCore.XcodeBuildControllerCreateXCFrameworkArgument],
        output _: AbsolutePath
    ) throws {}

    func build(
        _ target: XcodeBuildTarget,
        scheme: String,
        destination: XcodeBuildDestination?,
        rosetta: Bool,
        derivedDataPath: AbsolutePath?,
        clean: Bool,
        arguments: [XcodeBuildArgument]
    ) -> AsyncThrowingStream<SystemEvent<XcodeBuildOutput>, Error> {
        if let buildStub {
            return buildStub(
                target,
                scheme,
                destination,
                rosetta,
                derivedDataPath,
                clean,
                arguments
            ).asAsyncThrowingStream()
        } else {
            return AsyncThrowingStream {
                throw TestError(
                    "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to build"
                )
            }
        }
    }

//    func test(
//        _ target: XcodeBuildTarget,
//        scheme: String,
//        clean: Bool,
//        destination: XcodeBuildDestination,
//        rosetta: Bool,
//        derivedDataPath: AbsolutePath?,
//        resultBundlePath: AbsolutePath?,
//        arguments: [XcodeBuildArgument],
//        retryCount: Int,
//        testTargets: [TestIdentifier],
//        skipTestTargets: [TestIdentifier],
//        testPlanConfiguration: TestPlanConfiguration?
//    ) -> AsyncThrowingStream<SystemEvent<XcodeBuildOutput>, Error> {
//        if let testStub {
//            let results = testStub(
//                target,
//                scheme,
//                clean,
//                destination,
//                rosetta,
//                derivedDataPath,
//                resultBundlePath,
//                arguments,
//                retryCount,
//                testTargets,
//                skipTestTargets,
//                testPlanConfiguration
//            )
//            if let testErrorStub {
//                return AsyncThrowingStream {
//                    throw testErrorStub
//                }
//            } else {
//                return results.asAsyncThrowingStream()
//            }
//        } else {
//            return AsyncThrowingStream {
//                throw TestError(
//                    "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to test"
//                )
//            }
//        }
//    }

    var archiveStub: (
        (XcodeBuildTarget, String, Bool, AbsolutePath, [XcodeBuildArgument], AbsolutePath?)
            -> [SystemEvent<XcodeBuildOutput>]
    )?
    func archive(
        _ target: XcodeBuildTarget,
        scheme: String,
        clean: Bool,
        archivePath: AbsolutePath,
        arguments: [XcodeBuildArgument],
        derivedDataPath: AbsolutePath?
    ) -> AsyncThrowingStream<SystemEvent<XcodeBuildOutput>, Error> {
        if let archiveStub {
            return archiveStub(target, scheme, clean, archivePath, arguments, derivedDataPath)
                .asAsyncThrowingStream()
        } else {
            return AsyncThrowingStream {
                throw TestError(
                    "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to archive"
                )
            }
        }
    }

    var createXCFrameworkStub: (
        ([XcodeBuildControllerCreateXCFrameworkArgument], AbsolutePath)
            -> [SystemEvent<XcodeBuildOutput>]
    )?
    func createXCFramework(
        arguments: [XcodeBuildControllerCreateXCFrameworkArgument],
        output: AbsolutePath
    ) -> AsyncThrowingStream<SystemEvent<XcodeBuildOutput>, Error> {
        if let createXCFrameworkStub {
            return createXCFrameworkStub(arguments, output).asAsyncThrowingStream()
        } else {
            return AsyncThrowingStream {
                throw TestError(
                    "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to createXCFramework"
                )
            }
        }
    }

    var showBuildSettingsStub: ((XcodeBuildTarget, String, String, AbsolutePath?) -> [String: XcodeBuildSettings])?
    func showBuildSettings(
        _ target: XcodeBuildTarget,
        scheme: String,
        configuration: String,
        derivedDataPath: AbsolutePath?
    ) throws -> [String: XcodeBuildSettings] {
        if let showBuildSettingsStub {
            return showBuildSettingsStub(target, scheme, configuration, derivedDataPath)
        } else {
            throw TestError(
                "\(String(describing: MockXcodeBuildController.self)) received an unexpected call to showBuildSettings"
            )
        }
    }
}

extension Collection {
    func asAsyncThrowingStream() -> AsyncThrowingStream<Element, Error> {
        var iterator = makeIterator()
        return AsyncThrowingStream {
            iterator.next()
        }
    }
}
