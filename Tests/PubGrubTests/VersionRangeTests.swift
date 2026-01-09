import Foundation
import GekoCocoapods
import GekoSupport
import GekoSupportTesting
import XCTest

@testable import PubGrub

extension Int: Version {
    public var value: String {
        return String(self)
    }

    public var isPreRelease: Bool { false }

    public func asReleaseVersion() -> Int {
        return self
    }
}

let ranges: [VersionRange] = [
    VersionRange(segments: [
        VersionInterval(.included(835604476), .included(868945319))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(4271878183), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(1867651112)), 
        VersionInterval(.excluded(2290121357), .excluded(2934924770)), 
        VersionInterval(.included(2945223931), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(1511024005), .included(3562056503)), 
        VersionInterval(.excluded(3929185429), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(2401728272)), 
        VersionInterval(.included(3182527400), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(3201707638), .included(4186566586))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3897320760), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3439239401)), 
        VersionInterval(.excluded(3467733219), .excluded(4221125397))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3196577078)), 
        VersionInterval(.excluded(4118431056), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(765936544)), 
        VersionInterval(.excluded(1927902156), .excluded(3114613382)), 
        VersionInterval(.excluded(3525363887), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(1154670378)), 
        VersionInterval(.excluded(1585846258), .excluded(1849307079))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3289302667), .included(3625727195))
    ]),
    VersionRange(segments: [
    ]),
    VersionRange(segments: [
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3836127919))
    ]),
    VersionRange(segments: [
        VersionInterval(.included(2454641527), .included(3111071131)), 
        VersionInterval(.excluded(3397192033), .included(4094616702))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(2421536701), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(4030742971), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(1266929769)), 
        VersionInterval(.excluded(1741648130), .excluded(2374403127))
    ]),
    VersionRange(segments: [
        VersionInterval(.included(449782815), .included(3881051403)), 
        VersionInterval(.included(4191358744), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(1197750648)), 
        VersionInterval(.included(4284559137), .unbounded)
    ]),
    VersionRange(segments: [
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(179404547)), 
        VersionInterval(.excluded(4050174424), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(4048745259), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(8243380), .excluded(3401814660)), 
        VersionInterval(.excluded(3862818227), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2133033727)), 
        VersionInterval(.included(3328212565), .included(3525561485))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1233893705), .excluded(1643596537)), 
        VersionInterval(.included(2650427655), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(3542799134))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3891594052))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2279186165)), 
        VersionInterval(.included(4034426066), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(876049798), .included(3776194570))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(409951615), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(958153679), .excluded(2913312930)), 
        VersionInterval(.excluded(3769316055), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(3112181688))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2368067065)), 
        VersionInterval(.excluded(3720839798), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(565621336)), 
        VersionInterval(.excluded(3304072992), .excluded(3825661840)), 
        VersionInterval(.included(4137666400), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3449109092), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(2166284037), .excluded(2752380687))
    ]),
    VersionRange(segments: [
        VersionInterval(.included(899155118), .included(3666467095))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3681936191)), 
        VersionInterval(.excluded(4057270137), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(1012873754), .included(2213842262)), 
        VersionInterval(.excluded(3440381959), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1594273683), .included(3187232470)), 
        VersionInterval(.included(3205288219), .excluded(3481755144))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1030285057), .included(1214042716)), 
        VersionInterval(.included(3335279220), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3979362864), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(2432202635)), 
        VersionInterval(.excluded(3003144335), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(601429332)), 
        VersionInterval(.included(1095645943), .excluded(1385348290))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(2261120058), .included(3905787531))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(167372443)), 
        VersionInterval(.excluded(2924133001), .included(3837339722))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1267020761), .excluded(1649897950)), 
        VersionInterval(.excluded(1786961986), .excluded(4067224444))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(3088652589))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2621919798)), 
        VersionInterval(.excluded(4107327857), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(1823370407)), 
        VersionInterval(.excluded(2312903635), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(1378447129), .included(2660747510)), 
        VersionInterval(.excluded(3622711363), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(3834980303), .included(4038863059))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3163425450), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(881268784)), 
        VersionInterval(.included(3787628786), .excluded(3994136616))
    ]),
    VersionRange(segments: [
        VersionInterval(.included(1146190042), .excluded(2959203625))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1314464732), .excluded(2688813455)), 
        VersionInterval(.excluded(4025745758), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(2249232612)), 
        VersionInterval(.included(3353680968), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2700473933)), 
        VersionInterval(.excluded(3729554817), .excluded(3959469143)), 
        VersionInterval(.included(4107848792), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(429865840)), 
        VersionInterval(.included(2006662654), .excluded(3081770029)), 
        VersionInterval(.included(3317019626), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(1161100231), .excluded(1648536312)), 
        VersionInterval(.included(4145195582), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(1903210521)), 
        VersionInterval(.included(2687484132), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(1844713519)), 
        VersionInterval(.included(2853516643), .included(3101029129))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(1262150552), .included(1804707888)), 
        VersionInterval(.included(2483155278), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(738565874), .excluded(1988483207)), 
        VersionInterval(.excluded(4005692947), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(803773484), .included(3842208603))
    ]),
    VersionRange(segments: [
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(3688178996)), 
        VersionInterval(.excluded(3834714165), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(3530532709))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2964356378)), 
        VersionInterval(.excluded(4024013330), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(798959073), .excluded(3378785008))
    ]),
    VersionRange(segments: [
        VersionInterval(.excluded(3181526716), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.included(187855442), .included(2000248487)), 
        VersionInterval(.included(3291332896), .excluded(3853223690))
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .included(2510840971)), 
        VersionInterval(.included(2536287673), .unbounded)
    ]),
    VersionRange(segments: [
        VersionInterval(.unbounded, .excluded(2040362100))
    ]),
]

final class VersionRangeTests: GekoUnitTestCase {
    func testNegateIsDifferent() {
        for range in ranges {
            XCTAssertNotEqual(range.negate(), range)
        }
    }

    func testDoubleNegateIsIdentity() {
        for range in ranges {
            XCTAssertEqual(range.negate().negate(), range)
        }
    }

    func testNegateContainsOpposite() {
        for range in ranges {
            for version in stride(from: 0, to: Int.max, by: Int.max / 100) {
                XCTAssertNotEqual(range.contains(version), range.negate().contains(version))
            }
        }
    }

    func testIntersectionIsSymmetric() {
        for range1 in ranges {
            for range2 in ranges {
                XCTAssertEqual(range1.intersection(range2), range2.intersection(range1))
            }
        }
    }

    func testIntersectionWithAnyIsIdentity() {
        for range in ranges {
            XCTAssertEqual(VersionRange.any().intersection(range), range)
        }
    }

    func testIntersectionWithNoneIsNone() {
        for range in ranges {
            XCTAssertEqual(VersionRange.none().intersection(range), .none())
        }
    }

    func testIntersectionIsIdempotent() {
        for range1 in ranges {
            for range2 in ranges {
                XCTAssertEqual(range1.intersection(range2).intersection(range2), range1.intersection(range2))
            }
        }
    }

    func testIntersectionIsAssociative() {
        for range1 in ranges {
            for range2 in ranges {
                for range3 in ranges {
                    XCTAssertEqual(range1.intersection(range2).intersection(range3), range1.intersection(range2.intersection(range3)))
                }
            }
        }
    }

    func testIntersectionOfNegationIsNone() {
        for range in ranges {
            XCTAssertEqual(range.negate().intersection(range), .none())
        }
    }

    func testIntersectionContainsBoth() {
        for range1 in ranges {
            for range2 in ranges {
                for version in stride(from: 0, to: Int.max, by: Int.max / 100) {
                    XCTAssertEqual(range1.intersection(range2).contains(version), range1.contains(version) && range2.contains(version))
                }
            }
        }
    }

    func testUnionOfNegationIsAny() {
        for range in ranges {
            XCTAssertEqual(range.union(range.negate()), .any())
        }
    }

    func testUnionContainsEither() {
        for range1 in ranges {
            for range2 in ranges {
                let union = range1.union(range2)
                for version in stride(from: 0, to: Int.max, by: Int.max / 1000) {
                    XCTAssertEqual(union.contains(version), range1.contains(version) || range2.contains(version))
                }
            }
        }
    }

    func testAlwaysContainsExact() {
        for version in stride(from: 0, to: Int.max, by: Int.max / 100) {
            XCTAssertTrue(VersionRange.exact(version: version).contains(version))
        }
    }

    func testContainsNegation() {
        for range in ranges {
            for version in stride(from: 0, to: Int.max, by: Int.max / 100) {
                XCTAssertNotEqual(range.contains(version), range.negate().contains(version))
            }
        }
    }

    func containsIntersection() {
        for range in ranges {
            for version in stride(from: 0, to: Int.max, by: Int.max / 100) {
                XCTAssertNotEqual(
                    range.contains(version),
                    range.intersection(.exact(version: version)).contains(version)
                )
            }
        }
    }
}
