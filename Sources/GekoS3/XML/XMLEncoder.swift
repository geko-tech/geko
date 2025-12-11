#if canImport(FoundationXML)
import FoundationXML
#endif
import Foundation

protocol XMLEncodable {
    func toXMLElement() -> XMLElement
}

struct XMLEncoder {

    func encode(_ value: XMLEncodable) -> Data {
        let xmlDocument = XMLDocument(rootElement: value.toXMLElement())
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        return xmlDocument.xmlData(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
    }
}
