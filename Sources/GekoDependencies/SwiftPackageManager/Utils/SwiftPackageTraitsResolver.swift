import GekoSupport

struct SwiftPackageTraitsResolver {
    func enabledTraits(
        rootPackageInfo: PackageInfo,
        packageInfos: [String: PackageInfo]
    ) -> [String: Set<String>] {
        let normalizedPackageInfos = Dictionary(
            packageInfos.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let rootPackageTraits = rootPackageInfo.traits ?? []
        let rootEnabledTraits: Set<String> =
            if rootPackageTraits.contains(where: { $0.name == "default" }) {
                resolve(["default"], packageTraits: rootPackageTraits)
            } else {
                []
            }
        var result: [String: Set<String>] = [:]
        var changed = true

        while changed {
            changed = process(
                dependencies: rootPackageInfo.dependencies,
                parentTraits: rootEnabledTraits,
                packageInfos: normalizedPackageInfos,
                result: &result
            )

            for identity in normalizedPackageInfos.keys.sorted() {
                guard let packageInfo = normalizedPackageInfos[identity] else { continue }
                changed = process(
                    dependencies: packageInfo.dependencies,
                    parentTraits: result[identity] ?? [],
                    packageInfos: normalizedPackageInfos,
                    result: &result
                ) || changed
            }
        }

        return result
    }

    private func process(
        dependencies: [PackageDependency],
        parentTraits: Set<String>,
        packageInfos: [String: PackageInfo],
        result: inout [String: Set<String>]
    ) -> Bool {
        var changed = false

        for dependency in dependencies {
            let identity = dependency.identity.lowercased()
            let selectedTraits = dependency.traits.reduce(into: Set<String>()) { selectedTraits, trait in
                if let condition = trait.condition {
                    if !condition.isDisjoint(with: parentTraits) {
                        selectedTraits.insert(trait.name)
                    }
                } else {
                    selectedTraits.insert(trait.name)
                }
            }
            let resolvedTraits = resolve(
                selectedTraits,
                packageTraits: packageInfos[identity]?.traits ?? []
            )
            guard !resolvedTraits.isEmpty else { continue }

            let previousTraits = result[identity] ?? []
            result[identity, default: []].formUnion(resolvedTraits)
            changed = result[identity] != previousTraits || changed
        }

        return changed
    }

    private func resolve(
        _ traitNames: Set<String>,
        packageTraits: [PackageTrait]
    ) -> Set<String> {
        var resolvedTraits = traitNames
        var pendingTraits = Array(traitNames)

        while let traitName = pendingTraits.popLast() {
            guard let trait = packageTraits.first(where: { $0.name == traitName }) else { continue }
            for enabledTrait in trait.enabledTraits where resolvedTraits.insert(enabledTrait).inserted {
                pendingTraits.append(enabledTrait)
            }
        }

        return resolvedTraits
    }
}
