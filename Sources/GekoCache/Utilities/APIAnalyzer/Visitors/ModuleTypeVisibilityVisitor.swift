import Foundation
import SwiftSyntax

final class ModuleTypeVisibilityVisitor: SyntaxVisitor {
    var publicTypesNames = Set<String>()
    var nonPublicTypeNames = Set<String>()
    
    init() {
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node.name.text, node.modifiers, node.attributes)
        return .visitChildren
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node.name.text, node.modifiers, node.attributes)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node.name.text, node.modifiers, node.attributes)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node.name.text, node.modifiers, node.attributes)
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node.name.text, node.modifiers, node.attributes)
        return .visitChildren
    }
    
    private func collect(
        _ name: String,
        _ modifiers: DeclModifierListSyntax,
        _ attributes: AttributeListSyntax
    ) {
        let isVisible =
            modifiers.contains { ["public", "open"].contains($0.name.text) } ||
            attributes.contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "usableFromInline" }
        if isVisible {
            publicTypesNames.insert(name)
        } else {
            nonPublicTypeNames.insert(name)
        }
    }
}
