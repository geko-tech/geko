import Foundation

extension String: CodingKey {
    public init?(intValue: Int) {
        self.init(describing: intValue)
    }

    public init?(stringValue: String) {
        self.init(stringLiteral: stringValue)
    }

    public var stringValue: String {
        self
    }

    public var intValue: Int? {
        Int(self)
    }
}

private func decodeStringOrArray<C: CodingKey>(
    container: KeyedDecodingContainer<C>,
    for key: C
) -> [String] {
    if let single = try? container.decode(String.self, forKey: key) {
        return [single]
    } else if let array = try? container.decode([String].self, forKey: key) {
        return array
    }
    return []
}

private func decodeResourceBundles<C: CodingKey>(
    container: KeyedDecodingContainer<C>,
    for key: C
) throws -> [String: [String]] {
    guard container.contains(key) else {
        return [:]
    }

    let c = try container.nestedContainer(keyedBy: String.self, forKey: key)

    var result: [String: [String]] = [:]

    for k in c.allKeys {
        if let value = try? c.decode([String].self, forKey: k) {
            result[k] = value
        } else {
            let value = try c.decode(String.self, forKey: k)
            result[k] = [value]
        }
    }

    return result
}

public struct CocoapodsSpec {
    public let name: String
    public let moduleName: String?
    public let version: String
    public let swiftVersion: String?
    public let staticFramework: Bool?
    public let dependencies: [String: [String]]?
    public let platforms: Platforms?
    public let source: Source
    public let vendoredFrameworks: [String]
    public let vendoredLibraries: [String]

    public let sourceFiles: [String]
    public let excludeFiles: [String]
    public let publicHeaderFiles: [String]
    public let privateHeaderFiles: [String]
    public let projectHeaderFiles: [String]
    public let headerMappingsDir: String?
    public let moduleMap: ModuleMap?
    public let podTargetXCConfig: [String: SettingValue]
    public let infoPlist: [String: PlistValue]
    public let compilerFlags: [String]
    public let requiresArc: RequiresArc?

    public let frameworks: [String]
    public let weakFrameworks: [String]
    public let libraries: [String]

    public let resources: [String]
    public let resourceBundles: [String: [String]]
    public let preservePaths: [String]

    public let defaultSubspecs: [String]
    public let subspecs: [CocoapodsSpec]
    public let testSpecs: [CocoapodsSpec]
    public let appSpecs: [CocoapodsSpec]
    public let testType: TestType?
    public let requiresAppHost: Bool?
    public let appHostName: String?

    public let scriptPhases: [ScriptPhase]?
    public let prepareCommand: String?

    public let platformValues: [String: CocoapodsSpec]

    public var checksum: String = ""

    public init(
        name: String,
        moduleName: String?,
        version: String,
        swiftVersion: String?,
        staticFramework: Bool?,
        dependencies: [String: [String]]?,
        platforms: Platforms?,
        source: Source,
        vendoredFrameworks: [String],
        vendoredLibraries: [String],
        sourceFiles: [String],
        excludeFiles: [String],
        publicHeaderFiles: [String],
        privateHeaderFiles: [String],
        projectHeaderFiles: [String],
        headerMappingsDir: String?,
        moduleMap: ModuleMap?,
        podTargetXCConfig: [String: SettingValue],
        infoPlist: [String: PlistValue],
        compilerFlags: [String],
        requiresArc: RequiresArc?,
        frameworks: [String],
        weakFrameworks: [String],
        libraries: [String],
        resources: [String],
        resourceBundles: [String: [String]],
        preservePaths: [String],
        defaultSubspecs: [String],
        subspecs: [CocoapodsSpec],
        testSpecs: [CocoapodsSpec],
        appSpecs: [CocoapodsSpec],
        testType: TestType?,
        requiresAppHost: Bool?,
        appHostName: String?,
        scriptPhases: [ScriptPhase]?,
        platformValues: [String: CocoapodsSpec],
        prepareCommand: String?
    ) {
        self.name = name
        self.moduleName = moduleName
        self.version = version
        self.swiftVersion = swiftVersion
        self.staticFramework = staticFramework
        self.dependencies = dependencies
        self.platforms = platforms
        self.source = source
        self.vendoredFrameworks = vendoredFrameworks
        self.vendoredLibraries = vendoredLibraries
        self.sourceFiles = sourceFiles
        self.excludeFiles = excludeFiles
        self.publicHeaderFiles = publicHeaderFiles
        self.privateHeaderFiles = privateHeaderFiles
        self.projectHeaderFiles = projectHeaderFiles
        self.headerMappingsDir = headerMappingsDir
        self.moduleMap = moduleMap
        self.podTargetXCConfig = podTargetXCConfig
        self.infoPlist = infoPlist
        self.compilerFlags = compilerFlags
        self.requiresArc = requiresArc
        self.frameworks = frameworks
        self.weakFrameworks = weakFrameworks
        self.libraries = libraries
        self.resources = resources
        self.resourceBundles = resourceBundles
        self.preservePaths = preservePaths
        self.defaultSubspecs = defaultSubspecs
        self.subspecs = subspecs
        self.testSpecs = testSpecs
        self.appSpecs = appSpecs
        self.testType = testType
        self.requiresAppHost = requiresAppHost
        self.appHostName = appHostName
        self.scriptPhases = scriptPhases
        self.platformValues = platformValues
        self.prepareCommand = prepareCommand
    }

    public struct Source: Codable {
        public let http: String?
        public let sha256: String?
        public let git: String?
        public let tag: String?
        public let branch: String?
        public let commit: String?
        public let submodules: Bool?
        public let flatten: Bool?

        public init(
            http: String?,
            sha256: String?,
            git: String?,
            tag: String?,
            branch: String?,
            commit: String?,
            submodules: Bool?,
            flatten: Bool?
        ) {
            self.http = http
            self.sha256 = sha256
            self.git = git
            self.tag = tag
            self.branch = branch
            self.commit = commit
            self.submodules = submodules
            self.flatten = flatten
        }

        public static let none = Source(
            http: nil,
            sha256: nil,
            git: nil,
            tag: nil,
            branch: nil,
            commit: nil,
            submodules: nil,
            flatten: nil
        )
    }

    public struct Platforms: Equatable, Codable {
        public var osx: String?
        public var ios: String?
        public var tvos: String?
        public var visionos: String?
        public var watchos: String?

        public init(
            osx: String?,
            ios: String?,
            tvos: String?,
            visionos: String?,
            watchos: String?
        ) {
            self.osx = osx
            self.ios = ios
            self.tvos = tvos
            self.visionos = visionos
            self.watchos = watchos
        }
    }

    public enum ModuleMap: Codable {
        case none
        case generate
        case include(String)

        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()

            if let str = try? c.decode(String.self) {
                self = .include(str)
            } else if let bool = try? c.decode(Bool.self) {
                self = bool ? .generate : .none
            } else {
                self = .none
            }
        }
    }
    
    public enum RequiresArc: Codable {
        case enabled
        case disabled
        case include(Set<String>)
        
        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            
            if let str = try? c.decode(String.self) {
                self = .include([str])
            } else if let set = try? c.decode(Set<String>.self) {
                self = .include(set)
            } else if let bool = try? c.decode(Bool.self) {
                self = bool ? .enabled : .disabled
            } else {
                self = .enabled
            }
        }
    }

    public enum TestType: String, Equatable, Codable {
        case unit
        case ui
    }

    public struct ScriptPhase: Equatable, Codable {
        public enum ExecutionPosition: String, Equatable, Codable {
            case beforeCompile = "before_compile"
            case afterCompile = "after_compile"
            case beforeHeaders = "before_headers"
            case afterHeaders = "after_headers"
            case any

            enum CodingKeys: String, CodingKey {
                case rawValue
            }

            enum CodingError: Error {
                case unknownValue
            }

            public init(from decoder: Decoder) throws {
                self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .beforeCompile
            }
        }

        public var name: String
        public var shellPath: String?
        public var inputFiles: [String]?
        public var inputFileLists: [String]?
        public var outputFiles: [String]?
        public var outputFileLists: [String]?
        public var script: String
        public var showEnvVarsInLog: Bool?
        public var executionPosition: ExecutionPosition?
        public var dependencyFile: String?
        public var alwaysOutOfDate: Bool?

        public init(
            name: String,
            shellPath: String?,
            inputFiles: [String]?,
            inputFileLists: [String]?,
            outputFiles: [String]?,
            outputFileLists: [String]?,
            script: String,
            showEnvVarsInLog: Bool?,
            executionPosition: ExecutionPosition?,
            dependencyFile: String?,
            alwaysOutOfDate: Bool?
        ) {
            self.name = name
            self.shellPath = shellPath
            self.inputFiles = inputFiles
            self.inputFileLists = inputFileLists
            self.outputFiles = outputFiles
            self.outputFileLists = outputFileLists
            self.script = script
            self.showEnvVarsInLog = showEnvVarsInLog
            self.executionPosition = executionPosition
            self.dependencyFile = dependencyFile
            self.alwaysOutOfDate = alwaysOutOfDate
        }

        enum CodingKeys: String, CodingKey {
            case name
            case shellPath = "shell_path"
            case inputFiles = "input_files"
            case inputFileLists = "input_file_lists"
            case outputFiles = "output_files"
            case outputFileLists = "output_file_lists"
            case script
            case showEnvVarsInLog = "show_env_vars_in_log"
            case executionPosition = "execution_position"
            case dependencyFile = "dependency_file"
            case alwaysOutOfDate = "always_out_of_date"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            shellPath = try container.decodeIfPresent(String.self, forKey: .shellPath)
            inputFiles = try container.decodeStringOrArrayIfPresent(forKey: .inputFiles)
            inputFileLists = try container.decodeStringOrArrayIfPresent(forKey: .inputFileLists)
            outputFiles = try container.decodeStringOrArrayIfPresent(forKey: .outputFiles)
            outputFileLists = try container.decodeStringOrArrayIfPresent(forKey: .outputFileLists)
            script = try container.decode(String.self, forKey: .script)
            showEnvVarsInLog = try container.decodeStringBoolIfPresent(forKey: .showEnvVarsInLog)
            executionPosition = try container.decodeIfPresent(ExecutionPosition.self, forKey: .executionPosition)
            dependencyFile = try container.decodeIfPresent(String.self, forKey: .dependencyFile)
            alwaysOutOfDate = try container.decodeIfPresent(String.self, forKey: .alwaysOutOfDate) == "1"
        }
    }

    public enum SettingValue: Codable, Equatable {
        case string(String)
        case array([String])

        public init(from decoder: Decoder) throws {
            if var c = try? decoder.unkeyedContainer() {
                var result: [String] = []
                while !c.isAtEnd {
                    try result.append(c.decode(String.self))
                }
                self = .array(result)
            } else {
                let c = try decoder.singleValueContainer()
                if c.decodeNil() {
                    self = .string("")
                } else {
                    self = .string(try c.decode(String.self))
                }
            }
        }
    }

    public indirect enum PlistValue: Codable, Equatable {
        /// It represents a string value.
        case string(String)
        /// It represents an integer value.
        case integer(Int)
        /// It represents a floating value.
        case real(Double)
        /// It represents a boolean value.
        case boolean(Bool)
        /// It represents a dictionary value.
        case dictionary([String: PlistValue])
        /// It represents an array value.
        case array([PlistValue])

        public init(from decoder: Decoder) throws {
            if var c = try? decoder.unkeyedContainer() {
                var result: [PlistValue] = []
                while !c.isAtEnd {
                    try result.append(c.decode(PlistValue.self))
                }
                self = .array(result)
            } else if let c = try? decoder.container(keyedBy: String.self) {
                var result: [String: PlistValue] = [:]
                for key in c.allKeys {
                    result[key] = try c.decode(PlistValue.self, forKey: key)
                }
                self = .dictionary(result)
            } else {
                let c = try decoder.singleValueContainer()
                if let real = try? c.decode(Double.self) {
                    self = .real(real)
                } else if let bool = try? c.decode(Bool.self) {
                    self = .boolean(bool)
                } else if let int = try? c.decode(Int.self) {
                    self = .integer(int)
                } else {
                    self = try .string(c.decode(String.self))
                }
            }
        }
    }

    public enum CodingKeys: String, CodingKey {
        case name
        case moduleName = "module_name"
        case version
        case swiftVersion = "swift_version"
        case staticFramework = "static_framework"
        case dependencies
        case source
        case platforms
        case vendoredFrameworks = "vendored_frameworks"
        case vendoredLibraries = "vendored_libraries"
        case sourceFiles = "source_files"
        case excludeFiles = "exclude_files"
        case publicHeaderFiles = "public_header_files"
        case projectHeaderFiles = "project_header_files"
        case privateHeaderFiles = "private_header_files"
        case headerMappingsDir = "header_mappings_dir"
        case moduleMap = "module_map"
        case podTargetXCConfig = "pod_target_xcconfig"
        case infoPlist = "info_plist"
        case compilerFlags = "compiler_flags"
        case requiresArc = "requires_arc"
        case frameworks
        case weakFrameworks = "weak_frameworks"
        case libraries
        case resources
        case resourceBundles = "resource_bundles"
        case preservePaths = "preserve_path"
        case defaultSubspecs = "default_subspecs"
        case subspecs
        case ios
        case osx
        case watchos
        case tvos
        case visionos
        case testType = "test_type"
        case testSpecs = "testspecs"
        case appSpecs = "appspecs"
        case scriptPhases = "script_phases"
        case requiresAppHost = "requires_app_host"
        case appHostName = "app_host_name"
        case prepareCommand = "prepare_command"
    }
}

extension CocoapodsSpec: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        moduleName = try c.decodeIfPresent(String.self, forKey: .moduleName)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        swiftVersion = try c.decodeIfPresent(String.self, forKey: .swiftVersion)
        staticFramework = try c.decodeIfPresent(Bool.self, forKey: .staticFramework)
        dependencies = try c.decodeIfPresent([String: [String]].self, forKey: .dependencies)
        source = try c.decodeIfPresent(Source.self, forKey: .source) ?? .none
        platforms = try c.decodeIfPresent(Platforms.self, forKey: .platforms)

        vendoredFrameworks = decodeStringOrArray(container: c, for: .vendoredFrameworks)
        vendoredLibraries = decodeStringOrArray(container: c, for: .vendoredLibraries)
        sourceFiles = decodeStringOrArray(container: c, for: .sourceFiles)
        excludeFiles = decodeStringOrArray(container: c, for: .excludeFiles)
        publicHeaderFiles = decodeStringOrArray(container: c, for: .publicHeaderFiles)
        projectHeaderFiles = decodeStringOrArray(container: c, for: .projectHeaderFiles)
        privateHeaderFiles = decodeStringOrArray(container: c, for: .privateHeaderFiles)
        headerMappingsDir = try c.decodeIfPresent(String.self, forKey: .headerMappingsDir)
        moduleMap = try c.decodeIfPresent(ModuleMap.self, forKey: .moduleMap)
        podTargetXCConfig = try c.decodeIfPresent([String: SettingValue].self, forKey: .podTargetXCConfig) ?? [:]
        infoPlist = try c.decodeIfPresent([String: PlistValue].self, forKey: .infoPlist) ?? [:]
        compilerFlags = decodeStringOrArray(container: c, for: .compilerFlags)
        requiresArc = try c.decodeIfPresent(RequiresArc.self, forKey: .requiresArc)

        frameworks = decodeStringOrArray(container: c, for: .frameworks)
        weakFrameworks = decodeStringOrArray(container: c, for: .weakFrameworks)
        libraries = decodeStringOrArray(container: c, for: .libraries)

        resources = decodeStringOrArray(container: c, for: .resources)
        resourceBundles = try decodeResourceBundles(container: c, for: .resourceBundles)
        preservePaths = decodeStringOrArray(container: c, for: .preservePaths)

        defaultSubspecs = decodeStringOrArray(container: c, for: .defaultSubspecs)
        subspecs = try c.decodeIfPresent([CocoapodsSpec].self, forKey: .subspecs) ?? []

        testType = try c.decodeIfPresent(TestType.self, forKey: .testType)
        testSpecs = try c.decodeIfPresent([CocoapodsSpec].self, forKey: .testSpecs) ?? []
        appSpecs = try c.decodeIfPresent([CocoapodsSpec].self, forKey: .appSpecs) ?? []
        requiresAppHost = try c.decodeIfPresent(Bool.self, forKey: .requiresAppHost)
        appHostName = try c.decodeIfPresent(String.self, forKey: .appHostName)
        prepareCommand = try c.decodeIfPresent(String.self, forKey: .prepareCommand)

        if let phase = try? c.decodeIfPresent(ScriptPhase.self, forKey: .scriptPhases) {
            scriptPhases = [phase]
        } else {
            scriptPhases = try c.decodeIfPresent([ScriptPhase].self, forKey: .scriptPhases)
        }

        var platformValues: [String: CocoapodsSpec] = [:]
        if let ios = try c.decodeIfPresent(CocoapodsSpec.self, forKey: .ios) {
            platformValues[CocoapodsSpec.CodingKeys.ios.rawValue] = ios
        }
        if let osx = try c.decodeIfPresent(CocoapodsSpec.self, forKey: .osx) {
            platformValues[CocoapodsSpec.CodingKeys.osx.rawValue] = osx
        }
        if let watchos = try c.decodeIfPresent(CocoapodsSpec.self, forKey: .watchos) {
            platformValues[CocoapodsSpec.CodingKeys.watchos.rawValue] = watchos
        }
        if let tvos = try c.decodeIfPresent(CocoapodsSpec.self, forKey: .tvos) {
            platformValues[CocoapodsSpec.CodingKeys.tvos.rawValue] = tvos
        }
        if let visionos = try c.decodeIfPresent(CocoapodsSpec.self, forKey: .visionos) {
            platformValues[CocoapodsSpec.CodingKeys.visionos.rawValue] = visionos
        }

        self.platformValues = platformValues
    }
}

extension KeyedDecodingContainer {
    public func decodeStringOrArrayIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> [String]? {
        guard contains(key) else { return nil }
        if let singleString = try? decode(String.self, forKey: key) {
            return [singleString]
        } else if let array = try? decode([String].self, forKey: key) {
            return array
        }
        return nil
    }

    public func decodeStringBoolIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> Bool? {
        guard contains(key) else { return nil }
        guard let stringValue = try? decode(String.self, forKey: key) else { return nil }
        switch stringValue {
        case let value where value == "0":
            return false
        case let value where value == "1":
            return true
        default:
            return nil
        }
    }

    public func decodeStringOrBoolIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> String? {
        guard contains(key) else { return nil }
        if let bool = try? decode(Bool.self, forKey: key) {
            return String(bool)
        } else if let string = try? decode(String.self, forKey: key) {
            return string
        }
        return nil
    }

    public func decodeDictionaryArrayWithValueStringOrArrayIfPresent(
        forKey key: KeyedDecodingContainer<K>
            .Key
    ) throws -> [String: [String]]? {
        guard contains(key) else { return nil }
        if let dictWithArray = try? decode([String: [String]].self, forKey: key) {
            return dictWithArray
        } else if let dictWithString = try? decode([String: String].self, forKey: key) {
            var resultDict: [String: [String]] = [:]
            for (key, value) in dictWithString {
                resultDict[key] = [value]
            }
            return resultDict
        }
        return nil
    }
}
