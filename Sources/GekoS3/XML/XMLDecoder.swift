#if canImport(FoundationXML)
import FoundationXML
#endif
import Foundation

protocol XMLDecodable {
    static func fromXML(_ element: XMLElement) throws -> Self
}

struct XMLDecoder {

    private struct EmptyXML: Swift.Error {}

    func decode<T: XMLDecodable>(_ data: Data, type: T.Type) throws -> T {
        let xml = try Parser().parse(data)
        return try T.fromXML(xml)
    }

    func decode(_ data: Data) throws -> XMLElement {
        try Parser().parse(data)
    }

    private final class Parser: NSObject, XMLParserDelegate {
        private var root: XMLElement?
        private var stack = [XMLElement]()
        private var parseError: (any Error)?

        func parse(_ data: Data) throws -> XMLElement {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            if let parseError {
                throw parseError
            }
            if let root {
                return root
            }
            throw EmptyXML()
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            let node = XMLElement(name: elementName)
            if root == nil {
                root = node
            } else {
                stack.last?.addChild(node)
            }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            let trimmedCharacters = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let text = stack.last?.stringValue {
                stack.last?.stringValue = text + trimmedCharacters
            } else {
                stack.last?.stringValue = trimmedCharacters
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            stack.removeLast()
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
            self.parseError = parseError
        }
    }
}
