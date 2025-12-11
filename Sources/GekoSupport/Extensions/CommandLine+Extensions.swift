import Foundation

extension CommandLine {
    /// Arguments that intented to use from any geko command such as --verbose, --force, etc.
    ///
    /// Top level arguments are placed strictly before any subcommand.
    /// For example, invokation `geko --verbose --force fetch -r`
    /// Has only 2 top level arguments `--verbose` and `--force`.
    public static var topLevelArguments: [String] {
        return filterTopLevelArguments(from: CommandLine.arguments)
    }

    /// Arguments that intented to use from any geko command such as --verbose, --force, etc.
    ///
    /// Top level arguments are placed strictly before any subcommand.
    /// For example, invokation `geko --verbose --force fetch -r`
    /// Has only 2 top level arguments `--verbose` and `--force`.
    public static var subcommandArguments: [String] {
        return filterSubcommandArguments(from: CommandLine.arguments)
    }

    public static func filterTopLevelArguments(from args: consuming [String]) -> [String] {
        guard args.count > 0 else {
            // Should not be possible, but maybe...
            return args
        }

        // first argument is always name or path of the executable
        args.remove(at: 0)

        // Searching first argument, that has no dashes (such as `fetch`)
        guard let commandIdx = args.firstIndex(where: { !$0.hasPrefix("-") }) else {
            return args
        }

        // Remove all arguments after and including first subcommand
        args.removeLast(args.count - commandIdx)

        return args
    }

    public static func filterSubcommandArguments(from args: consuming [String]) -> [String] {
        guard args.count > 0 else {
            // Should not be possible, but maybe...
            return args
        }

        // remove first argument if it is a name or path of the executable
        args.remove(at: 0)

        // Searching first argument, that has no dashes (such as `fetch`)
        guard let commandIdx = args.firstIndex(where: { !$0.hasPrefix("-") }) else {
            return []
        }

        // Remove all arguments before first subcommand
        args.removeFirst(commandIdx)

        return args
    }
}
