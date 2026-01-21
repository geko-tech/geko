typealias cpu_type_t = UInt32
typealias cpu_subtype_t = UInt32

// adapted from https://github.com/apple-oss-distributions/dyld/blob/3d26957467bbec4f999a0c27ebe09b6fc186f5cd/libdyld/utils.cpp#L93

// this is a handrolled implementation to enable architecture detection independent from platform
// since geko supports both macos and linux

// MARK: - CPU types

private let CPU_ARCH_ABI64: cpu_type_t = 0x01000000
private let CPU_ARCH_ABI64_32: cpu_type_t = 0x02000000

private let CPU_TYPE_POWERPC: cpu_type_t = 18
private let CPU_TYPE_I386: cpu_type_t = 7
private let CPU_TYPE_X86_64: cpu_type_t = CPU_TYPE_I386 | CPU_ARCH_ABI64
private let CPU_TYPE_ARM: cpu_type_t = 12
private let CPU_TYPE_ARM64: cpu_type_t = CPU_TYPE_ARM | CPU_ARCH_ABI64
private let CPU_TYPE_ARM64_32: cpu_type_t = CPU_TYPE_ARM | CPU_ARCH_ABI64_32

// MARK: - CPU subtypes

private let CPU_SUBTYPE_POWERPC_ALL: cpu_subtype_t = 0
private let CPU_SUBTYPE_I386_ALL: cpu_subtype_t = 3
private let CPU_SUBTYPE_X86_64_ALL: cpu_subtype_t = 3
private let CPU_SUBTYPE_X86_64_H: cpu_subtype_t = 8
private let CPU_SUBTYPE_ARM_V7: cpu_subtype_t = 9
private let CPU_SUBTYPE_ARM_V7S: cpu_subtype_t = 11
private let CPU_SUBTYPE_ARM64_ALL: cpu_subtype_t = 0
private let CPU_SUBTYPE_ARM64_32_V8: cpu_subtype_t = 1
private let CPU_SUBTYPE_ARM_V6: cpu_subtype_t = 6
private let CPU_SUBTYPE_ARM_V6M: cpu_subtype_t = 14
private let CPU_SUBTYPE_ARM_V7K: cpu_subtype_t = 12
private let CPU_SUBTYPE_ARM_V7M: cpu_subtype_t = 15
private let CPU_SUBTYPE_ARM_V7EM: cpu_subtype_t = 16
private let CPU_SUBTYPE_ARM_V8M_MAIN: cpu_subtype_t = 17
private let CPU_SUBTYPE_ARM_V8_1M_MAIN: cpu_subtype_t = 19
private let CPU_SUBTYPE_ARM64_V8: cpu_subtype_t = 1
private let CPU_SUBTYPE_ARM64_32_ALL: cpu_subtype_t = 0
private let CPU_SUBTYPE_ARM64E: cpu_subtype_t = 2

private let CPU_SUBTYPE_MASK: cpu_subtype_t = 0xff000000

// MARK: - Implementation

private struct Architecture: Equatable {
    let cpuType: cpu_type_t
    let cpuSubtype: cpu_subtype_t
    let name: String

    init(cpuType: cpu_type_t, cpuSubtype: cpu_subtype_t) {
        self.name = ""
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
    }

    init(_ name: String, _ cpuType: cpu_type_t, _ cpuSubtype: cpu_subtype_t) {
        self.name = name
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        if lhs.cpuType != rhs.cpuType {
            return false
        }

        // do not compare cpu subtype feature flags
        if (lhs.cpuSubtype & ~CPU_SUBTYPE_MASK) != (rhs.cpuSubtype & ~CPU_SUBTYPE_MASK) {
            return false
        }

        // for arm64 compare everything, even high bits with feature flags
        if (lhs.cpuType == CPU_TYPE_ARM64) && (lhs.cpuSubtype != rhs.cpuSubtype) {
            return false
        }

        return true
    }
}

private let architectures: [Architecture] = [
    Architecture("ppc",             CPU_TYPE_POWERPC,    CPU_SUBTYPE_POWERPC_ALL), // ppc
    Architecture("i386",            CPU_TYPE_I386,       CPU_SUBTYPE_I386_ALL), // i386
    Architecture("x86_64",          CPU_TYPE_X86_64,     CPU_SUBTYPE_X86_64_ALL), // x86_64
    Architecture("x86_64h",         CPU_TYPE_X86_64,     CPU_SUBTYPE_X86_64_H), // x86_64h
    Architecture("armv7",           CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V7), // armv7
    Architecture("armv7s",          CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V7S), // armv7s
    Architecture("arm64",           CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64_ALL), // arm64
    Architecture("arm64e",          CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E | 0x80000000), // arm64e
    Architecture("arm64_32",        CPU_TYPE_ARM64_32,   CPU_SUBTYPE_ARM64_32_V8), // arm64_32
    Architecture("armv6",           CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V6), // armv6
    Architecture("armv6m",          CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V6M), // armv6m
    Architecture("armv7k",          CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V7K), // armv7k
    Architecture("armv7m",          CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V7M), // armv7m
    Architecture("armv7em",         CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V7EM), // armv7em
    Architecture("armv8m.main",     CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V8M_MAIN), // armv8m_main
    Architecture("armv8.1m.main",   CPU_TYPE_ARM,        CPU_SUBTYPE_ARM_V8_1M_MAIN), // armv8_1m_main

    // non-standard cpu subtypes
    Architecture("arm64",           CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64_V8), // arm64_alt
    Architecture("arm64_32",        CPU_TYPE_ARM64_32,   CPU_SUBTYPE_ARM64_32_ALL), // arm64_32_alt
    Architecture("arm64e.v1",       CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E | 0x81000000),  // arm64e_v1; future ABI version not supported
    Architecture("arm64e.old",      CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E), // arm64e_old; pre-ABI versioned

    Architecture("arm64e.kernel",   CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E | 0xC0000000), // arm64e_kernel
    Architecture("arm64e.kernel.v1",CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E | 0xC1000000), // arm64e_kernel_v1
    Architecture("arm64e.kernel.v2",CPU_TYPE_ARM64,      CPU_SUBTYPE_ARM64E | 0xC2000000), // arm64e_kernel_v2
]

func machoArchNameFromCpuType(cputype: cpu_type_t, cpusubtype: cpu_subtype_t) -> String? {
    let searchedArch = Architecture(cpuType: cputype, cpuSubtype: cpusubtype)

    for arch in architectures {
        if arch == searchedArch {
            if arch.name.hasPrefix("arm64e") {
                return "arm64e"
            }
            return arch.name
        }
    }

    return nil
}
