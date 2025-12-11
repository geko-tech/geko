import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport

final class GenerateService {
    private let opener: Opening
    private let clock: Clock
    private let timeTakenLoggerFormatter: TimeTakenLoggerFormatting
    private let generatorFactory: GeneratorFactorying
    private let manifestLoader: ManifestLoading
    private let configLoader: ConfigLoading

    init(
        clock: Clock = WallClock(),
        timeTakenLoggerFormatter: TimeTakenLoggerFormatting = TimeTakenLoggerFormatter(),
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        opener: Opening = Opener(),
        generatorFactory: GeneratorFactorying = GeneratorFactory(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader())
    ) {
        self.clock = clock
        self.timeTakenLoggerFormatter = timeTakenLoggerFormatter
        self.manifestLoader = manifestLoader
        self.opener = opener
        self.generatorFactory = generatorFactory
        self.configLoader = configLoader
    }

    func run(
        path: String?,
        noOpen: Bool,
        sources: Set<String>,
        scheme: String?,
        focusTests: Bool,
        noCache: Bool
    ) async throws {
        let timer = clock.startTimer()
        let path = try self.path(path)
        let config = try configLoader.loadConfig(path: path)
        let generator: Generating
        if !sources.isEmpty || scheme != nil || noCache {
            generator = try generatorFactory.focus(
                config: config,
                focusedTargets: sources,
                focusTests: focusTests,
                scheme: scheme
            )
        } else {
            generator = try generatorFactory.default(config: config)
        }
        let workspacePath = try await generator.generate(path: path)
        if !noOpen {
            try opener.open(path: workspacePath)
        }
        logger.notice("Project generated.", metadata: .success)
        logger.notice(timeTakenLoggerFormatter.timeTakenMessage(for: timer))
    }

    // MARK: - Helpers

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }
}
