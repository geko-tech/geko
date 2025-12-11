import Foundation

public final class GlobConverter {
    
    public init() {}
    
    public func toRegex(
        glob: String,
        extended: Bool = false,
        globstar: Bool = false,
        flags: String = ""
    ) -> String {
        var reStr = ""

        var inGroup = false

        let characters = Array(glob)
        var i = 0

        while i < characters.count {
            let c = characters[i]

            switch c {
            case "/", "$", "^", "+", ".", "(", ")", "=", "!", "|":
                reStr += "\\" + String(c)

            case "?":
                if extended {
                    reStr += "."
                    i += 1
                    continue
                }
                reStr += "\\?"

            case "[", "]":
                if extended {
                    reStr += String(c)
                } else {
                    reStr += "\\" + String(c)
                }

            case "{":
                if extended {
                    inGroup = true
                    reStr += "("
                } else {
                    reStr += "\\{"
                }

            case "}":
                if extended {
                    inGroup = false
                    reStr += ")"
                } else {
                    reStr += "\\}"
                }

            case ",":
                if inGroup {
                    reStr += "|"
                } else {
                    reStr += "\\,"
                }

            case "*":
                // Count consecutive stars
                var starCount = 1
                while i + 1 < characters.count && characters[i + 1] == "*" {
                    starCount += 1
                    i += 1
                }
                let prevChar = i - starCount >= 0 ? characters[i - starCount] : nil
                let nextChar = (i + 1) < characters.count ? characters[i + 1] : nil

                if !globstar {
                    reStr += ".*"
                } else {
                    let isGlobstar = starCount > 1 &&
                        (prevChar == "/" || prevChar == nil) &&
                        (nextChar == "/" || nextChar == nil)

                    if isGlobstar {
                        reStr += "((?:[^/]*(?:\\/|$))*)"
                        if nextChar == "/" {
                            i += 1 // Skip over "/"
                        }
                    } else {
                        reStr += "([^/]*)"
                    }
                }

            default:
                reStr += String(c)
            }
            i += 1
        }

        if !flags.contains("g") {
            reStr = "^" + reStr + "$"
        }
        
        return reStr
    }
}

