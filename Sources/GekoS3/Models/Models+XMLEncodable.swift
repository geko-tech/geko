#if canImport(FoundationXML)
import FoundationXML
#endif
import Foundation

extension CompleteMultipartUpload.Part: XMLEncodable {

    func toXMLElement() -> XMLElement {
        let rootElement = XMLElement(name: "Part")
        rootElement.addChild(XMLElement(name: "ETag", stringValue: eTag))
        rootElement.addChild(XMLElement(name: "PartNumber", stringValue: partNumber?.description))
        return rootElement
    }
}

extension CompleteMultipartUpload: XMLEncodable {

    func toXMLElement() -> XMLElement {
        let rootElement = XMLElement(name: "CompleteMultipartUpload")
        rootElement.setChildren(parts.map { $0.toXMLElement() })
        return rootElement
    }
}

extension Delete.Object: XMLEncodable {

    func toXMLElement() -> XMLElement {
        XMLElement(name: "Key", stringValue: key)
    }
}

extension Delete: XMLEncodable {

    func toXMLElement() -> XMLElement {
        let rootElement = XMLElement(name: "Delete")
        rootElement.setChildren(objects.map { $0.toXMLElement() })
        return rootElement
    }
}

extension CreateBucketConfiguration: XMLEncodable {

    func toXMLElement() -> XMLElement {
        let rootElement = XMLElement(name: "CreateBucketConfiguration")
        rootElement.addChild(XMLElement(name: "LocationConstraint", stringValue: locationConstraint))
        return rootElement
    }
}
