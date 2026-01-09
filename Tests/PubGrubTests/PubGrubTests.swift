import Foundation
import GekoCocoapods
import GekoSupport
import GekoSupportTesting
import XCTest

@testable import PubGrub

extension String: @retroactive Package {
    public var name: String {
        self
    }
}

extension CocoapodsVersion: @retroactive Version {
    public var isPreRelease: Bool {
        return preRelease != nil || !preReleaseSegments.isEmpty
    }

    public func asReleaseVersion() -> CocoapodsVersion {
        assert(CocoapodsVersion.maxSegmentCount == 5)

        return CocoapodsVersion(
            max(0, self.major),
            max(0, self.minor),
            max(0, self.patch),
            max(0, self.segment4),
            max(0, self.segment5)
        )
    }
}

private extension VersionSet {
    static func between(_ lower: CocoapodsVersion, _ upper: CocoapodsVersion) -> VersionSet<CocoapodsVersion> {
        return .init (
            release: .between(lower, upper),
            preRelease: .none()
        )
    }

    static func higherThan(version: CocoapodsVersion) -> VersionSet<CocoapodsVersion> {
        return .init (
            release: .higherThan(version: version),
            preRelease: .none()
        )
    }

    static func strictlyLowerThan(version: CocoapodsVersion) -> VersionSet<CocoapodsVersion> {
        return .init (
            release: .strictlyLowerThan(version: version),
            preRelease: .none()
        )
    }
}

final class PubGrubTests: GekoUnitTestCase {
    func test_noConflict() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("root", .init(1), ["foo": .between(.init(1), .init(2))])
        provider.add("foo", .init(1), ["bar": .between(.init(1), .init(2))])
        provider.add("bar", .init(1), [:])
        provider.add("bar", .init(2), [:])

        let solver = PubGrubSolver.init(dependencyProvider: provider)
        let solution = try await solver.resolve(package: "root", version: .init(1))

        let expectedSolution: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
            "bar": .init(1),
        ]

        XCTAssertEqual(expectedSolution, solution)
    }

    func test_avoidingConflictDuringDecisionMaking() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add(
            "root", .init(1),
            [
                "foo": .between(.init(1), .init(2)),
                "bar": .between(.init(1), .init(2)),
            ]
        )
        provider.add("foo", .init(1, 1), ["bar": .between(.init(2), .init(3))])
        provider.add("foo", .init(1), [:])
        provider.add("bar", .init(1), [:])
        provider.add("bar", .init(1, 1), [:])
        provider.add("bar", .init(2), [:])

        let solver = PubGrubSolver(dependencyProvider: provider)
        let solution = try await solver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
            "bar": .init(1, 1),
        ]

        XCTAssertEqual(expected, solution)
    }

    func test_conflictResolution() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("root", .init(1), ["foo": .higherThan(version: .init(1))])
        provider.add("foo", .init(2), ["bar": .between(.init(1), .init(2))])
        provider.add("foo", .init(1), [:])
        provider.add("bar", .init(1), ["foo": .between(.init(1), .init(2))])

        let solver = PubGrubSolver(dependencyProvider: provider)
        let solution = try await solver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
        ]

        XCTAssertEqual(expected, solution)
    }

    func test_conflictWithPartialSatisfier() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        // root 1.0.0 depends on foo ^1.0.0 and target ^2.0.0
        provider.add(
            "root", .init(1),
            [
                "foo": .between(.init(1), .init(2)),
                "target": .between(.init(2), .init(3)),
            ]
        )
        // foo 1.1.0 depends on left ^1.0.0 and right ^1.0.0
        provider.add(
            "foo", .init(1, 1),
            [
                "left": .between(.init(1), .init(2)),
                "right": .between(.init(1), .init(2)),
            ]
        )
        provider.add("foo", .init(1), [:])
        // left 1.0.0 depends on shared >=1.0.0
        provider.add("left", .init(1), ["shared": .higherThan(version: .init(1))])
        // right 1.0.0 depends on shared <2.0.0
        provider.add("right", .init(1), ["shared": .strictlyLowerThan(version: .init(2))])
        provider.add("shared", .init(2), [:])
        // shared 1.0.0 depends on target ^1.0.0
        provider.add("shared", .init(1), ["target": .between(.init(1), .init(2))])
        provider.add("target", .init(2), [:])
        provider.add("target", .init(1), [:])

        let solver = PubGrubSolver(dependencyProvider: provider)
        let solution = try await solver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
            "target": .init(2),
        ]

        XCTAssertEqual(expected, solution)
    }

    /// a1 dep on b and c
    /// b1 dep on d1
    /// b2 dep on d2 (not existing)
    /// c1 has no dep
    /// c2 dep on d3 (not existing)
    /// d1 has no dep
    ///
    /// Solution: a1, b1, c1, d1
    func test_doubleChoices() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("a", .init(1), ["b": .any(), "c": .any()])
        provider.add("b", .init(1), ["d": .exact(version: .init(1))])
        provider.add("b", .init(2), ["d": .exact(version: .init(2))])
        provider.add("c", .init(1), [:])
        provider.add("c", .init(2), ["d": .exact(version: .init(3))])
        provider.add("d", .init(1), [:])

        let expected: [String: CocoapodsVersion] = [
            "a": .init(1),
            "b": .init(1),
            "c": .init(1),
            "d": .init(1),
        ]

        let solver = PubGrubSolver(dependencyProvider: provider)
        let solution = try await solver.resolve(package: "a", version: .init(1))

        XCTAssertEqual(expected, solution)
    }

    func test_confusingWithLotsOfHoles() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add(
            "root", .init(1),
            [
                "foo": .any(),
                "baz": .any(),
            ]
        )

        for i in 1...6 {
            // bar does not exist in the tree
            provider.add("foo", .init(i), ["bar": .any()])
        }

        provider.add("baz", .init(1), [:])

        let solver = PubGrubSolver(dependencyProvider: provider)

        do {
            _ = try await solver.resolve(package: "root", version: .init(1))
            XCTFail("Solver should throw error")
        } catch let error as PubGrubError<String, CocoapodsVersion> {
            guard case var .noSolution(derivationTree) = error else {
                XCTFail("Solver shoud throw PubGrubError.noSolution")
                throw error
            }

            XCTAssertEqual(
                DefaultStringReporter.report(derivationTree: derivationTree),
                """
                Because there are no available versions for bar and foo 1.0 depends on bar, foo 1.0 is forbidden (1)
                And because there is no version of foo in { release: <1.0, >1.0 <2.0, >2.0 <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any }, foo { release: <2.0, >2.0 <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (2) (3)

                Because there are no available versions for bar and foo 2.0 depends on bar, foo 2.0 is forbidden (4)
                And because foo { release: <2.0, >2.0 <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (3), foo { release: <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (5) (6)

                Because there are no available versions for bar and foo 3.0 depends on bar, foo 3.0 is forbidden (7)
                And because foo { release: <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (6), foo { release: <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (8) (9)

                Because there are no available versions for bar and foo 4.0 depends on bar, foo 4.0 is forbidden (10)
                And because foo { release: <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (9), foo { release: <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (11) (12)

                Because there are no available versions for bar and foo 5.0 depends on bar, foo 5.0 is forbidden (13)
                And because foo { release: <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (12), foo { release: <6.0, >6.0, pre-release: any } is forbidden (14) (15)

                Because there are no available versions for bar and foo 6.0 depends on bar, foo 6.0 is forbidden (16)
                And because foo { release: <6.0, >6.0, pre-release: any } is forbidden (15), foo is forbidden (17)
                And because project depends on foo, package resolution failed (18)
                """
            )

            derivationTree.collapseNoVersions()

            XCTAssertEqual(
                DefaultStringReporter.report(derivationTree: derivationTree),
                """
                Because foo { release: <2.0, >2.0 <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } depends on bar and foo 2.0 depends on bar, foo { release: <3.0, >3.0 <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (1)
                And because foo 3.0 depends on bar, foo { release: <4.0, >4.0 <5.0, >5.0 <6.0, >6.0, pre-release: any } is forbidden (2)
                And because foo 4.0 depends on bar and foo 5.0 depends on bar, foo { release: <6.0, >6.0, pre-release: any } is forbidden (3)
                And because foo 6.0 depends on bar and project depends on foo, package resolution failed (4)
                """
            )
        }
    }

    func test_sharedDependencyWithOverlappingConstraints() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("a", .init(1), ["shared": .between(.init(2), .init(4))])
        provider.add("b", .init(1), ["shared": .between(.init(3), .init(5))])
        provider.add("shared", .init(2), [:])
        provider.add("shared", .init(3), [:])
        provider.add("shared", .init(3, 6, 9), [:])
        provider.add("shared", .init(4), [:])
        provider.add("shared", .init(5), [:])

        provider.add("root", .init(1), ["a": .exact(version: .init(1)), "b": .exact(version: .init(1))])

        let resolver = PubGrubSolver(dependencyProvider: provider)
        let result = try await resolver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "a": .init(1),
            "b": .init(1),
            "shared": .init(3, 6, 9),
        ]

        XCTAssertEqual(expected, result)
    }

    func test_sharedDependencyWhereDependentVersionInTurnAffectsOtherDependencies() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("foo", .init(1), [:])
        provider.add("foo", .init(1, 0, 1), ["bang": .exact(version: .init(1))])
        provider.add("foo", .init(1, 0, 2), ["whoop": .exact(version: .init(1))])
        provider.add("foo", .init(1, 0, 3), ["zoop": .exact(version: .init(1))])
        provider.add("bar", .init(1), ["foo": .strictlyLowerThan(version: .init(1, 0, 2))])
        provider.add("bang", .init(1), [:])
        provider.add("whoop", .init(1), [:])
        provider.add("zoop", .init(1), [:])

        // provider.add("root", .init(1), ["a": .exact(version: .init(1)), "b": .exact(version: .init(1))])
        provider.add(
            "root", .init(1),
            [
                "foo": .strictlyLowerThan(version: .init(1, 0, 3)),
                "bar": .exact(version: .init(1)),
            ]
        )

        let resolver = PubGrubSolver(dependencyProvider: provider)
        let result = try await resolver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1, 0, 1),
            "bar": .init(1),
            "bang": .init(1),
        ]

        XCTAssertEqual(expected, result)
    }

    func test_circularDependency() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("foo", .init(1), ["bar": .exact(version: .init(1))])
        provider.add("bar", .init(1), ["foo": .exact(version: .init(1))])

        provider.add("root", .init(1), ["foo": .exact(version: .init(1))])

        let resolver = PubGrubSolver(dependencyProvider: provider)
        let result = try await resolver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
            "bar": .init(1),
        ]

        XCTAssertEqual(expected, result)
    }

    func test_removedDependency() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("foo", .init(1), [:])
        provider.add("foo", .init(2), [:])
        provider.add("bar", .init(1), [:])
        provider.add("bar", .init(2), ["baz": .exact(version: .init(1))])
        provider.add("baz", .init(1), ["foo": .exact(version: .init(2))])

        provider.add("root", .init(1), ["foo": .exact(version: .init(1)), "bar": .any()])

        let resolver = PubGrubSolver(dependencyProvider: provider)
        let result = try await resolver.resolve(package: "root", version: .init(1))

        let expected: [String: CocoapodsVersion] = [
            "root": .init(1),
            "foo": .init(1),
            "bar": .init(1),
        ]

        XCTAssertEqual(expected, result)
    }

    func test_noVersionMatchesConstraint() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("foo", .init(2), [:])
        provider.add("foo", .init(2, 1, 3), [:])

        provider.add("root", .init(1), ["foo": .between(.init(1), .init(2))])

        let resolver = PubGrubSolver(dependencyProvider: provider)

        do {
            let solution = try await resolver.resolve(package: "root", version: .init(1))
            XCTFail("version resolution should fail, instead it produced solution \(solution)")
        } catch let error as PubGrubError<String, CocoapodsVersion> {
            guard case let .noSolution(derivationTree) = error else {
                XCTFail("Solver shoud throw PubGrubError.noSolution")
                throw error
            }

            XCTAssertEqual(
                DefaultStringReporter.report(derivationTree: derivationTree),
                "Because there is no version of foo in >=1.0 <2.0 and project depends on foo >=1.0 <2.0, package resolution failed (1)"
            )
        }
    }

    func test_noVersionMatchesCombinedConstraint() async throws {
        var provider: OfflineDependencyProvider<String, CocoapodsVersion> = OfflineDependencyProvider()

        provider.add("foo", .init(1), ["shared": .between(.init(2), .init(3))])
        provider.add("bar", .init(1), ["shared": .between(.init(2, 9), .init(4))])
        provider.add("shared", .init(2, 5), [:])
        provider.add("shared", .init(3, 5), [:])

        provider.add(
            "root", .init(1),
            [
                "foo": .exact(version: .init(1)),
                "bar": .exact(version: .init(1)),
            ]
        )

        let resolver = PubGrubSolver(dependencyProvider: provider)

        do {
            let solution = try await resolver.resolve(package: "root", version: .init(1))
            XCTFail("version resolution should fail, instead it produced solution \(solution)")
        } catch let error as PubGrubError<String, CocoapodsVersion> {
            guard case let .noSolution(derivationTree) = error else {
                XCTFail("Solver shoud throw PubGrubError.noSolution")
                throw error
            }

            XCTAssertEqual(
                DefaultStringReporter.report(derivationTree: derivationTree),
                """
                Because foo 1.0 depends on shared >=2.0 <3.0 and there is no version of shared in >=2.9 <3.0, foo 1.0 depends on shared >=2.0 <2.9 (1)
                And because bar 1.0 depends on shared >=2.9 <4.0, foo 1.0 is incompatible with bar 1.0 (2)
                And because project depends on foo 1.0 and project depends on bar 1.0, package resolution failed (3)
                """
            )
        }
    }
}
