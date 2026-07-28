import GekoSupport
import XCTest
@testable import GekoDependencies
@testable import GekoSupportTesting

final class SwiftPackageTraitsResolverTests: XCTestCase {
    func test_explicitRootTraitIsEnabled() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "FeatureA")]),
        ])
        let packageA = package(traits: [trait("FeatureA")])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertEqual(result["package-a"], ["FeatureA"])
    }

    func test_rootDefaultTraitEnablesConditionalDependencyTrait() {
        let root = PackageInfo.test(
            traits: [
                trait("default", enables: ["RootFeature"]),
                trait("RootFeature"),
            ],
            dependencies: [
                PackageDependency(
                    identity: "package-a",
                    traits: [PackageDependencyTrait(name: "FeatureA", condition: ["RootFeature"])]
                ),
            ]
        )
        let packageA = package(traits: [trait("FeatureA")])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertEqual(result["package-a"], ["FeatureA"])
    }

    func test_rootDefaultTraitRecursivelyEnablesConditionalDependencyTrait() {
        let root = PackageInfo.test(
            traits: [
                trait("default", enables: ["Intermediate"]),
                trait("Intermediate", enables: ["RootFeature"]),
                trait("RootFeature"),
            ],
            dependencies: [
                PackageDependency(
                    identity: "package-a",
                    traits: [PackageDependencyTrait(name: "FeatureA", condition: ["RootFeature"])]
                ),
            ]
        )
        let packageA = package(traits: [trait("FeatureA")])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertEqual(result["package-a"], ["FeatureA"])
    }

    func test_declaredRootTraitWithoutDefaultDoesNotEnableConditionalDependencyTrait() {
        let root = PackageInfo.test(
            traits: [
                trait("default", enables: ["DefaultFeature"]),
                trait("DefaultFeature"),
                trait("OptInFeature"),
            ],
            dependencies: [
                PackageDependency(
                    identity: "package-a",
                    traits: [PackageDependencyTrait(name: "FeatureA", condition: ["OptInFeature"])]
                ),
            ]
        )
        let packageA = package(traits: [trait("FeatureA")])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertNil(result["package-a"])
    }

    func test_defaultTraitRecursivelyEnablesConcreteTraits() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "default")]),
        ])
        let packageA = package(traits: [
            trait("default", enables: ["FeatureA"]),
            trait("FeatureA", enables: ["FeatureB"]),
            trait("FeatureB"),
        ])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertEqual(result["package-a"], ["default", "FeatureA", "FeatureB"])
    }

    func test_conditionalTransitiveTraitIsEnabledWhenParentTraitMatches() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "FeatureA")]),
        ])
        let packageA = package(
            traits: [trait("FeatureA")],
            dependencies: [
                PackageDependency(
                    identity: "package-b",
                    traits: [PackageDependencyTrait(name: "FeatureB", condition: ["FeatureA"])]
                ),
            ]
        )

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA, "package-b": package(traits: [trait("FeatureB")])]
        )

        XCTAssertEqual(result["package-b"], ["FeatureB"])
    }

    func test_conditionalTransitiveTraitIsDisabledWhenParentTraitDoesNotMatch() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "FeatureA")]),
        ])
        let packageA = package(
            traits: [trait("FeatureA")],
            dependencies: [
                PackageDependency(
                    identity: "package-b",
                    traits: [PackageDependencyTrait(name: "FeatureB", condition: ["OtherFeature"])]
                ),
            ]
        )

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA, "package-b": package(traits: [trait("FeatureB")])]
        )

        XCTAssertNil(result["package-b"])
    }

    func test_threeLevelPropagationIsIndependentOfDictionaryOrder() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "FeatureA")]),
        ])
        let packageA = package(
            traits: [trait("FeatureA")],
            dependencies: [
                PackageDependency(
                    identity: "package-b",
                    traits: [PackageDependencyTrait(name: "FeatureB", condition: ["FeatureA"])]
                ),
            ]
        )
        let packageB = package(
            traits: [trait("FeatureB")],
            dependencies: [
                PackageDependency(
                    identity: "package-c",
                    traits: [PackageDependencyTrait(name: "FeatureC", condition: ["FeatureB"])]
                ),
            ]
        )

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: [
                "package-c": package(traits: [trait("FeatureC")]),
                "package-b": packageB,
                "package-a": packageA,
            ]
        )

        XCTAssertEqual(result["package-c"], ["FeatureC"])
    }

    func test_cyclicTraitDefinitionsTerminate() {
        let root = PackageInfo.test(dependencies: [
            PackageDependency(identity: "package-a", traits: [PackageDependencyTrait(name: "default")]),
        ])
        let packageA = package(traits: [
            trait("default", enables: ["FeatureA"]),
            trait("FeatureA", enables: ["default"]),
        ])

        let result = SwiftPackageTraitsResolver().enabledTraits(
            rootPackageInfo: root,
            packageInfos: ["package-a": packageA]
        )

        XCTAssertEqual(result["package-a"], ["default", "FeatureA"])
    }

    private func package(
        traits: [PackageTrait],
        dependencies: [PackageDependency] = []
    ) -> PackageInfo {
        PackageInfo.test(traits: traits, dependencies: dependencies)
    }

    private func trait(_ name: String, enables enabledTraits: [String] = []) -> PackageTrait {
        PackageTrait(enabledTraits: enabledTraits, name: name, description: nil)
    }
}
