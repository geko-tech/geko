import Foundation
import GekoCocoapods
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

final class CocoapodsRepoGitSourceUpdater {
    private let gitHandler: GitHandling
    private let fileHandler: FileHandling
    private let pathProvider: CocoapodsPathProviding

    private let config: Config
    private let source: String
    private let repoUpdate: Bool
    private let localRepoName: String

    init(
        config: Config,
        source: String,
        repoUpdate: Bool,
        pathProvider: CocoapodsPathProviding,
        gitHandler: GitHandling = GitHandler(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.config = config
        self.source = source
        self.repoUpdate = repoUpdate
        self.pathProvider = pathProvider
        self.gitHandler = gitHandler
        self.fileHandler = fileHandler
        localRepoName = reponame(for: source)
    }

    func download() async throws {
        let repoCacheDir = pathProvider.repoCacheDir(repoName: localRepoName)

        if !fileHandler.exists(repoCacheDir.appending(component: ".git")) {
            logger.info("Cloning '\(source)'")
            try gitHandler.clone(url: source, to: repoCacheDir)
        } else if repoUpdate {
            logger.info("Updating '\(source)'")
            try gitHandler.checkout(id: "master", in: repoCacheDir)
            try gitHandler.pull(in: repoCacheDir)
        }
    }
}
