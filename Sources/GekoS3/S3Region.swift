import Foundation

public struct S3Region: Sendable, RawRepresentable, Equatable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Africa (Cape Town)
    public static var afsouth1: S3Region { .init(rawValue: "af-south-1") }
    // Asia Pacific (Hong Kong)
    public static var apeast1: S3Region { .init(rawValue: "ap-east-1") }
    // Asia Pacific (Taipei)
    public static var apeast2: S3Region { .init(rawValue: "ap-east-2") }
    // Asia Pacific (Tokyo)
    public static var apnortheast1: S3Region { .init(rawValue: "ap-northeast-1") }
    // Asia Pacific (Seoul)
    public static var apnortheast2: S3Region { .init(rawValue: "ap-northeast-2") }
    // Asia Pacific (Osaka)
    public static var apnortheast3: S3Region { .init(rawValue: "ap-northeast-3") }
    // Asia Pacific (Mumbai)
    public static var apsouth1: S3Region { .init(rawValue: "ap-south-1") }
    // Asia Pacific (Hyderabad)
    public static var apsouth2: S3Region { .init(rawValue: "ap-south-2") }
    // Asia Pacific (Singapore)
    public static var apsoutheast1: S3Region { .init(rawValue: "ap-southeast-1") }
    // Asia Pacific (Sydney)
    public static var apsoutheast2: S3Region { .init(rawValue: "ap-southeast-2") }
    // Asia Pacific (Jakarta)
    public static var apsoutheast3: S3Region { .init(rawValue: "ap-southeast-3") }
    // Asia Pacific (Melbourne)
    public static var apsoutheast4: S3Region { .init(rawValue: "ap-southeast-4") }
    // Asia Pacific (Malaysia)
    public static var apsoutheast5: S3Region { .init(rawValue: "ap-southeast-5") }
    // Asia Pacific (Thailand)
    public static var apsoutheast7: S3Region { .init(rawValue: "ap-southeast-7") }
    // Canada (Central)
    public static var cacentral1: S3Region { .init(rawValue: "ca-central-1") }
    // Canada West (Calgary)
    public static var cawest1: S3Region { .init(rawValue: "ca-west-1") }
    // China (Beijing)
    public static var cnnorth1: S3Region { .init(rawValue: "cn-north-1") }
    // China (Ningxia)
    public static var cnnorthwest1: S3Region { .init(rawValue: "cn-northwest-1") }
    // Europe (Frankfurt)
    public static var eucentral1: S3Region { .init(rawValue: "eu-central-1") }
    // Europe (Zurich)
    public static var eucentral2: S3Region { .init(rawValue: "eu-central-2") }
    // EU ISOE West
    public static var euisoewest1: S3Region { .init(rawValue: "eu-isoe-west-1") }
    // Europe (Stockholm)
    public static var eunorth1: S3Region { .init(rawValue: "eu-north-1") }
    // Europe (Milan)
    public static var eusouth1: S3Region { .init(rawValue: "eu-south-1") }
    // Europe (Spain)
    public static var eusouth2: S3Region { .init(rawValue: "eu-south-2") }
    // Europe (Ireland)
    public static var euwest1: S3Region { .init(rawValue: "eu-west-1") }
    // Europe (London)
    public static var euwest2: S3Region { .init(rawValue: "eu-west-2") }
    // Europe (Paris)
    public static var euwest3: S3Region { .init(rawValue: "eu-west-3") }
    // EU (Germany)
    public static var euscdeeast1: S3Region { .init(rawValue: "eusc-de-east-1") }
    // Israel (Tel Aviv)
    public static var ilcentral1: S3Region { .init(rawValue: "il-central-1") }
    // Middle East (UAE)
    public static var mecentral1: S3Region { .init(rawValue: "me-central-1") }
    // Middle East (Bahrain)
    public static var mesouth1: S3Region { .init(rawValue: "me-south-1") }
    // Mexico (Central)
    public static var mxcentral1: S3Region { .init(rawValue: "mx-central-1") }
    // South America (Sao Paulo)
    public static var saeast1: S3Region { .init(rawValue: "sa-east-1") }
    // US East (N. Virginia)
    public static var useast1: S3Region { .init(rawValue: "us-east-1") }
    // US East (Ohio)
    public static var useast2: S3Region { .init(rawValue: "us-east-2") }
    // US West (N. California)
    public static var uswest1: S3Region { .init(rawValue: "us-west-1") }
    // US West (Oregon)
    public static var uswest2: S3Region { .init(rawValue: "us-west-2") }
    // other S3Region
    public static func other(_ name: String) -> S3Region { .init(rawValue: name) }
}
