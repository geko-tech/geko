/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ProjectDescription

/// Provides functionality related a process's enviorment.
public enum ProcessEnv {

    /// Returns a dictionary containing the current environment.
    public static var vars: [String: String] { _vars }
    private static var _vars = ProcessInfo.processInfo.environment

    /// Invalidate the cached env.
    public static func invalidateEnv() {
        _vars = ProcessInfo.processInfo.environment
    }

    /// Set the given key and value in the process's environment.
    public static func setVar(_ key: String, value: String) throws {
      #if os(Windows)
        guard TSCLibc._putenv("\(key)=\(value)") == 0 else {
            throw ProcessSystemError.setenv(Int32(GetLastError()), key)
        }
      #else
        guard setenv(key, value, 1) == 0 else {
            throw ProcessSystemError.setenv(errno, key)
        }
      #endif
        invalidateEnv()
    }

    /// Unset the give key in the process's environment.
    public static func unsetVar(_ key: String) throws {
      #if os(Windows)
        guard TSCLibc._putenv("\(key)=") == 0 else {
            throw ProcessSystemError.unsetenv(Int32(GetLastError()), key)
        }
      #else
        guard unsetenv(key) == 0 else {
            throw ProcessSystemError.unsetenv(errno, key)
        }
      #endif
        invalidateEnv()
    }

    /// `PATH` variable in the process's environment (`Path` under Windows).
    public static var path: String? {
#if os(Windows)
        let pathArg = "Path"
#else
        let pathArg = "PATH"
#endif
        return vars[pathArg]
    }

    /// The current working directory of the process.
    public static var cwd: AbsolutePath? {
        return localFileSystem.currentWorkingDirectory
    }

    /// Change the current working directory of the process.
    public static func chdir(_ path: AbsolutePath) throws {
        let path = path.pathString
#if os(Windows)
        guard path.withCString(encodedAs: UTF16.self, {
            SetCurrentDirectoryW($0)
        }) else {
            throw ProcessSystemError.chdir(Int32(GetLastError()), path)
        }
#elseif os(macOS)
        guard Darwin.chdir(path) == 0 else {
            throw ProcessSystemError.chdir(errno, path)
        }
#else
        guard Foundation.chdir(path) == 0 else {
            throw ProcessSystemError.chdir(errno, path)
        }
#endif
    }
}
