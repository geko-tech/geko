import Foundation
import ProjectDescription

public struct PackageResolved: Decodable {
    public let version: Int
    public let pins: [Pin]

    public struct Pin: Decodable {
        public let identity: String
        public let kind: String
        public let location: String
        public let state: State?

        public enum State: Decodable {
            case branch(branch: String, revision: String)
            case version(version: String, revision: String)
            case unknown

            enum CodingKeys: String, CodingKey {
                case branch, revision, version
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let branch = try? container.decode(String.self, forKey: .branch),
                   let revision = try? container.decode(String.self, forKey: .revision) {
                    self = .branch(branch: branch, revision: revision)
                    return
                }

                if let version = try? container.decode(String.self, forKey: .version),
                   let revision = try? container.decode(String.self, forKey: .revision)
                    {
                    self = .version(version: version, revision: revision)
                    return
                }

                self = .unknown
            }
        }
    }
}

public final class ProjectDescriptionBranchVersionParser {
    public init() {}

    public func parse(packageResolvedPath: AbsolutePath) throws -> String? {
        let data = try FileHandler.shared.readFile(packageResolvedPath)
        let packageResolved: PackageResolved = try parseJson(data, context: .file(path: packageResolvedPath))

        guard
            let projectDesciptionPin = packageResolved.pins.first(where: { $0.identity == "projectdescription" }),
            case let .branch(branch, _) = projectDesciptionPin.state
        else {
            logger.error("projectdescription not found in Package.resolved: \(packageResolvedPath)")
            return nil
        }

        return branch
    }
}
