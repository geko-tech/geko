import Foundation
import GekoSupport
import GekoGraph
import GekoCore
import GekoCache
import ProjectDescription

public final class CacheTargetsPhaseScriptExecutionTask: CacheTask {
    struct TargetWithScripts {
        let graphTarget: GraphTarget
        let scripts: [TargetScript]
        
        var projectDirPath: AbsolutePath {
            AbsolutePath(stringLiteral: graphTarget.project.xcodeProjPath.dirname)
        }
    }
    
    struct PreparedScript {
        let shellPath: String
        let script: String
        let projectDirPath: AbsolutePath
        let env: [String: String]
        
        init(
            shellPath: String,
            script: String,
            projectDirPath: AbsolutePath,
            env: [String: SettingValue]
        ) {
            self.shellPath = shellPath
            self.script = script
            self.projectDirPath = projectDirPath
            self.env = Dictionary(uniqueKeysWithValues: env.map { key, value in
                switch value {
                case let .string(stringValue):
                    return (key, stringValue)
                case let .array(arrayValue):
                    return (key, arrayValue.joined(separator: ","))
                }
            })
        }
        
        var command: [String] {
            var command = [shellPath, "-c"]
            // Change current execution directory to pbxproject location
            let script = """
            cd \(projectDirPath)
            \(script)
            """
            command.append(script)
            
            return command
        }
    }
    
    // MARK: - Attributes
    
    @Atomic var preparedScripts: [PreparedScript] = []
    
    // MARK: - Init
    
    public init() {}
    
    // MARK: - CacheTask

    public func run(context: inout CacheContext) async throws {
        /// Dictionary, where the key is the name of the script, and the value is additional env for resolve
        let scriptEnvs = Dictionary(uniqueKeysWithValues: context.cacheProfile.scripts.map { ($0.name, $0.envKeys) })
        let enforceExplicitDependencies = context.config.generationOptions.enforceExplicitDependencies
        guard !scriptEnvs.isEmpty else { return }
        
        logger.info("Executing target shell scripts: \(scriptEnvs.keys.joined(separator: ", "))", metadata: .subsection)
        
        guard let graph = context.graph else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        
        let graphTraverser = GraphTraverser(graph: graph)
        graphTraverser.warmup()
        let targets = filterTargetsWithBuildPhaseScripts(
            graphTraverser: graphTraverser,
            scriptEnvs: scriptEnvs
        )
        let buildSettingsResolver = BuildSettingsResolver(
            graphTraverser: graphTraverser,
            projectDescriptorGenerator: ProjectDescriptorGenerator(enforceExplicitDependencies: enforceExplicitDependencies)
        )

        try targets.forEach(context: .concurrent) { target in
            try target.scripts.forEach(context: .concurrent) { script in
                if let shellScript = script.embeddedScript {
                    let (modifiedShellScript, env) = try replaceVariablesWithValues(
                        shellScript: shellScript,
                        target: target,
                        buildSettingsResolver: buildSettingsResolver
                    )
                    let additionalEnvironment = try resolveAdditionalEnv(
                        target: target,
                        scriptName: script.name,
                        scriptEnvs: scriptEnvs,
                        buildSettingsResolver: buildSettingsResolver
                    )
                    let mergedEnvironment = env.merging(additionalEnvironment) { $1 }
                    _preparedScripts.modify {
                        $0.append(
                            PreparedScript(
                                shellPath: script.shellPath,
                                script: modifiedShellScript,
                                projectDirPath: target.projectDirPath,
                                env: mergedEnvironment
                            )
                        )
                    }
                }
            }
        }

        try _preparedScripts.wrappedValue.forEach(context: .concurrent) { script in
            _ = try System.shared.capture(script.command, verbose: false, environment: script.env)
        }
    }
    
    // MARK: - Helpers

    /// Filter available projects and scripts
    func filterTargetsWithBuildPhaseScripts(
        graphTraverser: GraphTraversing,
        scriptEnvs: [String: [String]]
    ) -> [TargetWithScripts] {
        var targets = [TargetWithScripts]()
        let internalTargets = graphTraverser.allInternalTargets()
        for target in internalTargets {
            let filteredShellScripts = target.target.scripts.filter { scriptEnvs.keys.contains($0.name) }
            guard !filteredShellScripts.isEmpty else { continue }
            targets.append(TargetWithScripts(
                graphTarget: target,
                scripts: filteredShellScripts
            ))
        }
        return targets
    }

    /// Cache profile provide scripts and additonal environment, this method resolve them
    func resolveAdditionalEnv(
        target: TargetWithScripts,
        scriptName: String,
        scriptEnvs: [String: [String]],
        buildSettingsResolver: BuildSettingsResolving
    ) throws -> [String: SettingValue] {
        guard let envKeys = scriptEnvs[scriptName] else { return [:] }
        var environment = [String: SettingValue]()
        try envKeys.forEach(context: .concurrent) { envKey in
            let resolvedVariable = try buildSettingsResolver.commonResolveBuildSetting(
                key: envKey,
                project: target.graphTarget.project,
                for: target.graphTarget.target,
                resolveAgaintsXCConfig: true
            )
            environment[envKey] = resolvedVariable
        }
        return environment
    }

    /// Method will be resolve and replace environment variables for provided script
    func replaceVariablesWithValues(
        shellScript: String,
        target: TargetWithScripts,
        buildSettingsResolver: BuildSettingsResolving,
        resolvedVariables: [String: SettingValue]? = nil
    ) throws -> (script: String, env: [String: SettingValue]) {
        let shellScriptRange = NSRange(location: 0, length: shellScript.utf16.count)
        let regex = BuildSettingsConstants.captureVariableInBuildConfigRegex
        let matches = regex.matches(in: shellScript, range: shellScriptRange)

        guard let match = matches.first else {
            // No variables left, return the value unchanged
            return (shellScript, resolvedVariables ?? [:])
        }

        var resolvedVariables = resolvedVariables ?? [:]
        var variableReference = ""
        var variable = ""

        for rangeIndex in 0 ..< match.numberOfRanges {
            let matchRange = match.range(at: rangeIndex)
            // Extract the substring matching the capture group
            if let substringRange = Range(matchRange, in: shellScript) {
                let capture = String(shellScript[substringRange])
                if capture.contains("$") {
                    variableReference = capture
                } else {
                    variable = capture
                }
            }
        }

        let resolvedVariable: SettingValue
        if let existedValue = resolvedVariables[variable] {
            resolvedVariable = existedValue
        } else {
            resolvedVariable = try buildSettingsResolver.commonResolveBuildSetting(
                key: variable,
                project: target.graphTarget.project,
                for: target.graphTarget.target,
                resolveAgaintsXCConfig: true
            )
            resolvedVariables[variable] = resolvedVariable
        }

        switch resolvedVariable {
        case let .string(stringValue):
            let updatedShellScript = shellScript.replacingOccurrences(of: variableReference, with: stringValue)
            return try replaceVariablesWithValues(
                shellScript: updatedShellScript,
                target: target,
                buildSettingsResolver: buildSettingsResolver,
                resolvedVariables: resolvedVariables
            )
        case let .array(arrayValue):
            let updatedShellScript = shellScript.replacingOccurrences(
                of: variableReference,
                with: arrayValue.joined(separator: ",")
            )
            return try replaceVariablesWithValues(
                shellScript: updatedShellScript,
                target: target,
                buildSettingsResolver: buildSettingsResolver,
                resolvedVariables: resolvedVariables
            )
        }
    }
}
