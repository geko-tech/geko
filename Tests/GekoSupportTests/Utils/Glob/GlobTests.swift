import Foundation
import XCTest
import Glob

final class GlobTests: XCTestCase {
    private func checkGlob(pattern: String, against strings: [String: Bool]) throws {
        let glob = try Glob(pattern)

        for (string, shouldMatch) in strings {
            if shouldMatch {
                XCTAssertTrue(glob.match(string: string), "'\(pattern)' should match string '\(string)'")
            } else {
                XCTAssertFalse(glob.match(string: string), "'\(pattern)' should not match string '\(string)'")
            }
        }
    }

    func test_emptyPattern() throws {
        try checkGlob(pattern: "", against: [
            "": false,
            "a": false,
            "aa": false,
            "/": false,
        ])
    }

    func test_plainChars() throws {
        try checkGlob(pattern: "a", against: [
            "": false,
            "a": true,
            "b": false,
            "aa": false,
        ])
        try checkGlob(pattern: "я", against: [
            "": false,
            "a": false,
            "b": false,
            "aa": false,
            "я": true,
            "яя": false,
        ])
        try checkGlob(pattern: "[я]", against: [
            "": false,
            "a": false,
            "b": false,
            "aa": false,
            "я": true,
            "яя": false,
        ])
        try checkGlob(pattern: "[\\]]", against: [
            "": false,
            "a": false,
            "b": false,
            "]": true,
        ])
        try checkGlob(pattern: "[!я]", against: [
            "": false,
            "a": true,
            "b": true,
            "aa": false,
            "ч": true,
            "я": false,
            "яя": false,
        ])
        try checkGlob(pattern: "aa", against: [
            "": false,
            "a": false,
            "b": false,
            "aa": true,
            "aaa": false,
        ])
    }
    
    func test_ranges() throws {
        try checkGlob(pattern: "[б-ч]", against: [
            "": false,
            "a": false,
            "b": false,
            "aa": false,
            "а": false,
            "б": true,
            "ч": true,
            "ш": false,
            "я": false,
            "чч": false,
        ])
        try checkGlob(pattern: "[!б-ч]", against: [
            "": false,
            "a": true,
            "b": true,
            "aa": false,
            "а": true,
            "б": false,
            "ч": false,
            "ш": true,
            "я": true,
            "чч": false,
            "бч": false,
        ])
        try checkGlob(pattern: "[\\b-\\y]", against: [
            "": false,
            "-": false,
            "a": false,
            "b": true,
            "g": true,
            "y": true,
            "z": false,
        ])
        try checkGlob(pattern: "[\\б-\\ч]", against: [
            "": false,
            "-": false,
            "a": false,
            "b": false,
            "g": false,
            "y": false,
            "z": false,
            "а": false,
            "б": true,
            "ч": true,
            "ш": false,
        ])
    }

    func test_set() throws {
        try checkGlob(pattern: "[бl🙂ч]", against: [
            "": false,
            "a": false,
            "aa": false,
            "b": false,
            "l": true,
            "ll": false,
            "а": false,
            "б": true,
            "г": false,
            "ч": true,
            "чч": false,
            "🙂": true,
            "🙂🙂": false,
            "ш": false,
            "я": false,
        ])
        try checkGlob(pattern: "[!бl🙂ч]", against: [
            "": false,
            "a": true,
            "b": true,
            "aa": false,
            "а": true,
            "б": false,
            "г": true,
            "ч": false,
            "🙂": false,
            "🙂🙂": false,
            "ш": true,
            "я": true,
            "чч": false,
            "бч": false,
        ])
        try checkGlob(pattern: "[\\!a\\-z]", against: [
            "": false,
            "!": true,
            "!!": false,
            "a": true,
            "-": true,
            "b": false,
            "x": false,
            "y": false,
            "z": true,
        ])
        try checkGlob(pattern: "[\\!a\\-z]!", against: [
            "": false,
            "!": false,
            "!!": true,
            "!!!": false,
            "a": false,
            "-": false,
            "b": false,
            "x": false,
            "y": false,
            "z": false,
        ])
        try checkGlob(pattern: "[\\!б\\-чf\\]]", against: [
            "": false,
            "!": true,
            "!!": false,
            "a": false,
            "f": true,
            "-": true,
            "b": false,
            "x": false,
            "y": false,
            "z": false,
            "а": false,
            "б": true,
            "ч": true,
            "]": true,
        ])
        try checkGlob(pattern: "[!a\\-z]!", against: [
            "": false,
            "!": false,
            "!!": true,
            "a!": false,
            "🙂!": true,
            "!!!": false,
            "a": false,
            "-": false,
            "b": false,
            "x!": true,
            "y!": true,
            "z!": false,
        ])
    }

    func test_globs() throws {
        try checkGlob(pattern: "*", against: [
            "": true,
            "a": true,
            "b": true,
            "aa": true,
            "aaa.bbb": true,
            "aaa/aaa": false,
            "aaa.bbb/aaa": false,
        ])
        try checkGlob(pattern: "**", against: [
            "": true,
            "a": true,
            "b": true,
            "aa": true,
            "aaa.bbb": true,
            "aaa/aaa": true,
            "aaa.bbb/aaa": true,
        ])
        try checkGlob(pattern: "**/*", against: [
            "": true,
            "a": true,
            "b": true,
            "aa": true,
            "aaa.bbb": true,
            "aaa/aaa": true,
            "aaa.bbb/aaa": true,
        ])
        try checkGlob(pattern: "**/*swift", against: [
            "": false,
            "a": false,
            "b": false,
            "aa": false,
            "aaa.bbb": false,
            "aaa/aaa": false,
            "aaa.bbb/aaa": false,
            ".swift": true,
            "file.swift": true,
            "folder/.swift": true,
            "folder/file.swift": true,
            "folder/subfolder/.swift": true,
            "folder/subfolder/file.swift": true,
            "folder/subfolder/subfolder2/subfolder3/.swift": true,
            "folder/subfolder/subfolder2/subfolder3/subfolder4/file.swift": true,
            "folder/subfolder/subfolder2/subfolder3/subfolder4/file.swif": false,
            "folder/subfolder/subfolder2/subfolder3/subfolder4/file.wift": false,
            "folder/subfolder/subfolder2/subfolder3/subfolder4/fileswift": true,
        ])
        try checkGlob(pattern: "**/s*", against: [
            "": false,
            "start": true,
            "sfile": true,
            "as": false,
            "as/s": true,
            "as/as": false,
            "as/s/as": false,
            "as/s/s": true,
        ])
        try checkGlob(pattern: "**/s*", against: [
            "": false,
            "start": true,
            "sfile": true,
            "as": false,
            "as/s": true,
            "as/as": false,
            "as/s/as": false,
            "as/s/s": true,
        ])
    }
    
    func test_alterations() throws {
        try checkGlob(pattern: "folder/{**/*.swift,*.png}", against: [
            "file.swift": false,
            "file.swif": false,
            "folder/file.swift": true,
            "folder/file.png": true,
            "folder/file.swif": false,
            "folder/subfolder/file.swift": true,
            "folder/subfolder/file.png": false,
            "folder/subfolder/file.swif": false,
        ])
        try checkGlob(pattern: "{a,b}{c,d}{e,f}", against: [
            "aaa": false,
            "ace": true,
            "acf": true,
            "ade": true,
            "adf": true,
            "bce": true,
            "bcf": true,
            "bde": true,
            "bdf": true,
            "bdd": false,
        ])
        try checkGlob(pattern: "**/*{name,tests}*/**/*", against: [
            "name": false,
            "name/file": true,
            "name2/file": true,
            "2name/file": true,
            "2name2/file": true,
            "nam/file": false,
            "nam/nam/file": false,
            "nam/name/file": true,
            "nam/name2/file": true,
            "nam/2name/file": true,
            "nam/2name2/file": true,
            "nam/2name2/a/b/c/d/file": true,
            "a/b/c/d/2name2/file": true,
            "a/b/c/d/2name2": false,
            "a/b/c/d/2name2/a/b/c/d/file": true,
            "a/b/c/d/2tests2/a/b/c/d/file": true,
            "a/b/c/d/2test2/a/b/c/d/file": false,
            "atestss/b/c/d/a/b/c/d/file": true,
            "b/c/d/a/b/c/d/atestss/file": true,
            "name/tests/name/tests/name/file": true,
            "nam/test/nam/test/nam/file": false,
        ])
    }

    func test_braceErrors() {
        XCTAssertThrowsSpecific(
            try Glob(","),
            GlobNDFAError.commaOutsideOfBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("}"),
            GlobNDFAError.unbalancedBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("}}"),
            GlobNDFAError.unbalancedBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("{,,,,},,,,,}"),
            GlobNDFAError.unbalancedBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("{abc}def}"),
            GlobNDFAError.unbalancedBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("{abc"),
            GlobNDFAError.unbalancedBraces
        )
        XCTAssertThrowsSpecific(
            try Glob("{abc,{test}"),
            GlobNDFAError.unbalancedBraces
        )

        XCTAssertNoThrow(try Glob("\\,"))
        XCTAssertNoThrow(try Glob("\\}"))
        XCTAssertNoThrow(try Glob("{abc}def\\}"))
        XCTAssertNoThrow(try Glob("\\{abc\\}def\\}"))
    }

    func test_bracketErrors() {
        XCTAssertThrowsSpecific(
            try Glob("["),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("]"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[abcd"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[a-c"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[!abcd"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[!a-c"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[!a-c]]"),
            GlobNDFAError.unbalancedBrackets
        )
        XCTAssertThrowsSpecific(
            try Glob("[!a-c]["),
            GlobNDFAError.unbalancedBrackets
        )

        XCTAssertNoThrow(try Glob("\\["))
        XCTAssertNoThrow(try Glob("\\]"))
        XCTAssertNoThrow(try Glob("[a]"))
        XCTAssertNoThrow(try Glob("[abcd]"))
        XCTAssertNoThrow(try Glob("[!abcd]"))
        XCTAssertNoThrow(try Glob("[!abбl🙂чcd\\]]"))
    }
}
