import Foundation
import GekoCore
import ArgumentParser

struct ManifestOptions: ParsableArguments {
    @Option(
        name: [
            .customLong("pp", withSingleDash: true),
            .customLong("project-profile")
        ],
        help: "Generate profile name from Geko/generate_profiles.yml"
    )
    var projectProfile: String? = nil

    @Option(
        name: [.customShort("f")],
        help: .init(
            "Pass a flag to manifest",
            discussion: """
            You can use -f to pass flags to manifest to be able to enable some functionality on demand.
            Geko converts each passed flag to environment variable 'GEKO_MANIFEST_FLAG_<flag> that you can utilize using convenient `Flag["flag"]` subscript.
            """,
            valueName: "flag"
        )
    )
    var flags: [String] = []
}
