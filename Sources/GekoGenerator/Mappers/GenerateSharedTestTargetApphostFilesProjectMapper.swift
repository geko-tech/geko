import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

public final class GenerateSharedTestTargetApphostFilesProjectMapper: ProjectMapping {
    private let derivedDirectoryName: String
    private let sourcesDirectoryName: String

    public init(
        derivedDirectoryName: String = Constants.DerivedDirectory.name,
        sourcesDirectoryName: String = Constants.DerivedDirectory.sources
    ) {
        self.derivedDirectoryName = derivedDirectoryName
        self.sourcesDirectoryName = sourcesDirectoryName
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        for t in 0 ..< project.targets.count {
            let targetName = project.targets[t].name

            guard
                sideTable.targets[targetName]?.flags
                    .contains(.sharedTestTargetAppHost) == true
            else {
                continue
            }

            let targetDerivedPath = project.path
                .appending(component: derivedDirectoryName)
                .appending(component: targetName)
            let sourcesPath = targetDerivedPath
                .appending(component: sourcesDirectoryName)
            let storyboardPath = targetDerivedPath
                .appending(component: "LaunchScreen.storyboard")

            let (sourceFileSideEffects, sourceFiles) = generateAppHostSourceFiles(path: sourcesPath)
            let storyboardSideEffect = generateAppHostStoryboard(path: storyboardPath)

            project.targets[t].sources = [SourceFiles(paths: sourceFiles)]
            project.targets[t].resources = [ResourceFileElement(path: storyboardPath)]

            sideEffects.append(contentsOf: sourceFileSideEffects)
            sideEffects.append(storyboardSideEffect)
        }

        return sideEffects
    }

    private func generateAppHostSourceFiles(path: AbsolutePath) -> ([SideEffectDescriptor], [AbsolutePath]) {
        let appDelegateContents = """
        import Foundation
        import UIKit

        final class AppDelegate: UIResponder, UIApplicationDelegate {

            var window: UIWindow?

            func application(
                _ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
                window = UIWindow(frame: UIScreen.main.bounds)
                window?.rootViewController = UIViewController()
                window?.makeKeyAndVisible()

                return true
            }
        }

        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
        """

        let sourceFilePath = path.appending(component: "main.swift")
        return (
            [
                .file(.init(
                    path: sourceFilePath,
                    contents: appDelegateContents.data(using: .utf8)
                ))
            ],
            [sourceFilePath]
        )
    }

    private func generateAppHostStoryboard(path: AbsolutePath) -> SideEffectDescriptor {
        let launchScreenContents = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="13122.16" systemVersion="17A277" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
          <dependencies>
            <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="13104.12"/>
            <capability name="Safe area layout guides" minToolsVersion="9.0"/>
            <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
          </dependencies>
          <scenes>
            <!--View Controller-->
            <scene sceneID="EHf-IW-A2E">
              <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                  <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                    <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
                    <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                    <color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                    <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                  </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
              </objects>
              <point key="canvasLocation" x="53" y="375"/>
            </scene>
          </scenes>
        </document>
        """

        return .file(.init(
            path: path,
            contents: launchScreenContents.data(using: .utf8)
        ))
    }
}
