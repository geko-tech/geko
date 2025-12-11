import ArgumentParser
import Foundation
import GekoCore

/// Category that can be cleaned
enum CleanCategory: ExpressibleByArgument {
    static let allCases = CacheCategory.allCases.map { .global($0) } + [Self.dependencies, Self.cocoapods, Self.logs]
    static let defaultCases = CacheCategory.allCases.map { .global($0) } + [Self.cocoapods, Self.logs]

    /// The global cache
    case global(CacheCategory)

    /// The local dependencies cache
    case dependencies
    
    /// The local cache of cocoapods
    case cocoapods
    
    /// The local logs
    case logs

    var defaultValueDescription: String {
        switch self {
        case let .global(cacheCategory):
            return cacheCategory.rawValue
        case .dependencies:
            return "dependencies"
        case .cocoapods:
            return "cocoapods"
        case .logs:
            return "logs"
        }
    }

    init?(argument: String) {
        if let cacheCategory = CacheCategory(rawValue: argument) {
            self = .global(cacheCategory)
        } else if argument == "dependencies" {
            self = .dependencies
        } else if argument == "cocoapods" {
            self = .cocoapods
        } else if argument == "logs" {
            self = .logs
        } else {
            return nil
        }
    }
}

public struct CleanCommand: ParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "clean",
            abstract: "Clean all the artifacts stored locally.\nBy default, artifacts older than 7 days are removed from these categories: \(CleanCategory.defaultCases.map { $0.defaultValueDescription }.joined(separator: ", "))"
        )
    }

    @Argument(help: "The cache and artifact categories to be cleaned. If no category is specified, everything is cleaned.\nOptions: \(CleanCategory.allCases.map { $0.defaultValueDescription }.joined(separator: ", "))")
    var cleanCategories: [CleanCategory] = []

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project that should be cleaned.",
        completion: .directory
    )
    var path: String?
    
    @Flag(
        name: .long,
        help: "Completely removes all locally stored geko artifacts."
    )
    var full: Bool = false

    public func run() throws {
        let categories: [CleanCategory]
        if cleanCategories.isEmpty {
            categories = full ? CleanCategory.allCases : CleanCategory.defaultCases
        } else {
            categories = cleanCategories
        }
        
        try CleanService().run(
            categories: categories,
            path: path,
            full: full
        )
    }
}
