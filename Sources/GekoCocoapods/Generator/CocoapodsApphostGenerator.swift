import Foundation
import ProjectDescription
import GekoSupport

final class CocoapodsApphostGenerator {
    func createAppHost(
        spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath
    ) throws -> (ProjectDescription.Target, [SideEffectDescriptor]) {
        let name = "AppHost-\(spec.targetName)"
        let productName = name.replacingOccurrences(of: "-", with: "_")
        let destinations = spec.destinations()
        let bundleId = "org.cocoapods.\(name)"
        let deploymentsTargets = spec.deploymentTargets()
        let (appHostMainFile, appHostSideEffect) = try createAppHostMainFile(
            targetName: name,
            path: path
        )
        let (launchScreen, launchScreenSideEffect) = try createAppHostLaunchScreen(
            targetName: name,
            path: path
        )
        let infoPlist: [String: Plist.Value] = [
            "CFBundleDevelopmentRegion": .string("ru_RU"),
            "UILaunchStoryboardName": .string("LaunchScreen"),
            "NSAppTransportSecurity": .dictionary(
                ["NSAllowsArbitraryLoads": .boolean(true)]
            ),
        ]

        let sources = [SourceFiles(stringLiteral: appHostMainFile.pathString)]

        let settingsDict: SettingsDictionary = ["OTHER_LDFLAGS": .string("-ObjC")]

        let appHost = Target(
            name: name,
            destinations: destinations,
            product: .app,
            productName: productName,
            bundleId: bundleId,
            deploymentTargets: deploymentsTargets,
            infoPlist: InfoPlist.extendingDefault(with: infoPlist),
            sources: SourceFilesList(sourceFiles: sources),
            resources: ResourceFileElements(resources: [
                ResourceFileElement(
                    stringLiteral: launchScreen.pathString
                )
            ]),
            settings: .settings(
                base: settingsDict,
                debug: [:],
                release: [:],
                defaultSettings: .essential(excluding: Set(settingsDict.keys))
            )
        )

        return (appHost, [appHostSideEffect, launchScreenSideEffect])
    }

    fileprivate func createAppHostMainFile(
        targetName: String,
        path: AbsolutePath
    ) throws -> (AbsolutePath, SideEffectDescriptor) {
        let fileContent = """
            #import <Foundation/Foundation.h>
            #import <UIKit/UIKit.h>

            @interface CPTestAppHostAppDelegate : UIResponder <UIApplicationDelegate>

            @property (nonatomic, strong) UIWindow *window;

            @end

            @implementation CPTestAppHostAppDelegate

            - (BOOL)application:(UIApplication *)__unused application didFinishLaunchingWithOptions:(NSDictionary *)__unused launchOptions
            {
                self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
                self.window.rootViewController = [UIViewController new];

                [self.window makeKeyAndVisible];

                return YES;
            }

            @end

            int main(int argc, char *argv[])
            {
                @autoreleasepool
                {
                    return UIApplicationMain(argc, argv, nil, NSStringFromClass([CPTestAppHostAppDelegate class]));
                }
            }
            """

        let derivedPath = path.appending(component: Constants.DerivedDirectory.name)
        let folderPath = derivedPath.appending(components: [targetName, Constants.DerivedDirectory.sources])
        let filePath = folderPath.appending(component: "main.m")

        let fileDescriptor = SideEffectDescriptor.file(.init(path: filePath, contents: fileContent.data(using: .utf8), state: .present))

        return (filePath, fileDescriptor)
    }

    fileprivate func createAppHostLaunchScreen(
        targetName: String,
        path: AbsolutePath
    ) throws -> (AbsolutePath, SideEffectDescriptor) {
        // Remove storyboard and make main screen from code
        let fileContent = """
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

        let derivedPath = path.appending(component: Constants.DerivedDirectory.name)
        let folderPath = derivedPath.appending(components: [targetName, Constants.DerivedDirectory.resources])
        let filePath = folderPath.appending(component: "LaunchScreen.storyboard")

        let fileDescriptor = SideEffectDescriptor.file(.init(path: filePath, contents: fileContent.data(using: .utf8), state: .present))

        return (filePath, fileDescriptor)
    }
}
