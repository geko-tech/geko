## Geko 1.2.0
• [patch] misc: prettify manifest compilation output log (#131)
Geko [minor] --handoff option for generate (#129)
Geko [minor] Structured xcodebuild json logs (#128)
Geko [minor] Structured json logs (#127)
Geko [minor] Add logs quiet mode & inspect targets for files command (#126)
Geko [patch] Fix SPM bundles and dependencies sanitize (#125)
Geko [patch] Fix issue - PBXResourcesBuildPhase is missing for buildable resource folders (#124)
Geko [patch] speed up manifest loading (#112)
* Geko [patch] speed up manifest loading
* Geko [patch] Fix manifest extension initialization
• [patch] fix swiftlangVersion parsing on linux (#121)
Geko [patch] Add build progress bar (#119)
Geko [patch] Prevent graph traversal stack overflows (#117)
* Geko [patch] Make graph algorithms stack-safe
* Geko [patch] Make GraphTraverser stack-safe
* Geko [patch] Make ModuleMapMapper stack-safe
* Geko [patch] Make static product linting stack-safe
* Geko [patch] Make XCFramework traversal stack-safe
* Geko [patch] Restore some comments
* Geko [patch] Simplify iterative graph traversal
* Geko [patch] Move traversal frame types closer to usage
* Geko [patch] Simplify iterative graph traversal state
• [minor] The '• test' and '• build' command interfaces have been extended (#108)
Geko [patch] Fix unused external dependencies added as .path missing warning (#118)
Geko [patch] Test coverage (#116)
Geko [minor] add SwiftPM package traits support (#114)
* Geko [minor] add SwiftPM package traits support
* Geko [minor] support trait-conditioned SwiftPM build settings
* Geko [patch] resolve root SwiftPM default traits
Geko [patch] Fix issue with incorrect invalidate of swiftmodule hashes when updates (#115)
Geko [patch] prevent duplicate SwiftPM dependency downloads (#113)
* Geko [patch] prevent duplicate SwiftPM dependency downloads
* Geko [patch] preserve configured Swift tools version
Geko [patch] Fix dependencies-only cache focus (#111)

## Geko 1.1.0
Geko [patch] Fixed extra focus on test modules of runnable target (#110)
Geko [patch] Add logs for swiftmodule caching task (#109)
• [minor] feat: support plan files for generate command (#107)
• [patch] feat: project profiles support for test and build commands (#106)
• [minor] feat: --trace option for tree command (#105)

## Geko 1.0.11
• [patch] fix: missing ignoreDependencies filter when forming linkable dependencies list (#104)

## Geko 1.0.10
• [patch] fix: skip swiftinterface cache if xcframework contains _CodeSignature (#103)

## Geko 1.0.9
• [patch] fix strErrorFilter hanging

## Geko 1.0.8
• [patch] improve error reporting in SimulatorController (#101)

## Geko 1.0.7
• [patch] fix linux autoupdate crash on bundle init (#100)
* • [patch] fix linux autoupdate crash on bundle init; fix FileHandler incorrect behaviour on linux

## Geko 1.0.6
• [patch] fix percent encoded path (#99)

## Geko 1.0.5
• [patch] Suppress objc class duplication warnings when loading plugins (#95)

## Geko 1.0.4
• [patch] fix: crash in CircularDependencyLinter due to stack overflow (#92)
• [patch] perf: String contains optimizations and CommentedString.validString optimization (#91)
• [patch] Restoring tests with plugins and Google Maps (#89)

## Geko 1.0.3
• [patch] perf: optimized path components calculation (#86)
• [patch] help-env command (#80)
• [patch] added workspace (#84)
• [patch] fix: Fix issue with external redundant deps (#74)

## Geko 1.0.2
geko [patch] replace String(describing:) with _typeName call (#68)

## Geko 1.0.1
geko [patch] fix: missing directories in resource build phase when using podspec (#66)

## Geko 1.0.0
geko [patch] fix: release (#61)
geko [patch] fix pd and revert (#58)
geko [patch] fix pd (#57)
geko [major] for release (#56)

