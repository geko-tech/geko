import Foundation
import SwiftSyntax
import ProjectDescription

final class SwiftFileAPIVisitor: SyntaxVisitor {
    // MARK: - Public Attributes
    
    var hasPublicAPI = false
    var reasons = Set<UnsafeApiReason>()
    var diagnostics: [UnsafeApiDiagnostic] = []
    
    // MARK: - Private Attributes
    private let path: AbsolutePath
    private let converter: SourceLocationConverter
    private let publicTypeNames: Set<String>
    private let nonPublicTypeNames: Set<String>
    private let macroNames: Set<String>
    
    init(
        path: AbsolutePath,
        converter: SourceLocationConverter,
        publicTypeNames: Set<String>,
        nonPublicTypeNames: Set<String>,
        macroNames: Set<String>
    ) {
        self.path = path
        self.converter = converter
        self.publicTypeNames = publicTypeNames
        self.nonPublicTypeNames = nonPublicTypeNames
        self.macroNames = macroNames
        super.init(viewMode: .sourceAccurate)
    }
    
    // MARK: - Visits
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isVisible(Syntax(node)) else {
            return .visitChildren
        }
        writeStat(Syntax(node), attributes: node.attributes)
        for binding in node.bindings where binding.typeAnnotation == nil {
            unsafeReasonDiagnostic(.inferredType, node: Syntax(binding), representation: node.trimmedDescription)
        }
        return .visitChildren
    }
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind { visitDeclaration(node, attributes: node.attributes) }
    
    private func visitDeclaration<T: DeclSyntaxProtocol>(_ node: T, attributes: AttributeListSyntax) -> SyntaxVisitorContinueKind {
        if isVisible(Syntax(node)) { writeStat(Syntax(node), attributes: attributes) }
        return .visitChildren
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = node.extendedType.trimmedDescription
        let knownNonPublic = !extendedName.contains(".")
            && nonPublicTypeNames.contains(extendedName)
            && !publicTypeNames.contains(extendedName)
        let hasVisibleMember = node.memberBlock.members.contains { isVisible(Syntax($0.decl)) }
        if (node.inheritanceClause != nil && !knownNonPublic) || hasVisibleMember || isVisible(Syntax(node)) {
            writeStat(Syntax(node), attributes: node.attributes)
        }
        return .visitChildren
    }
    
    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !node.attributes.isEmpty, let variable = enclosingVariable(Syntax(node)), isVisible(Syntax(variable)) else {
            return .visitChildren
        }
        writeStat(Syntax(node), attributes: node.attributes)
        return .visitChildren
    }
    
    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        if isInsideVisibleEnum(Syntax(node)) { writeStat(Syntax(node), attributes: node.attributes) }
        return .visitChildren
    }
    
    override func visit(_ node: OperatorDeclSyntax) -> SyntaxVisitorContinueKind {
        hasPublicAPI = true
        return .skipChildren
    }

    override func visit(_ node: PrecedenceGroupDeclSyntax) -> SyntaxVisitorContinueKind {
        hasPublicAPI = true
        return .skipChildren
    }
    
    // MARK: - Statistic
    
    private func writeStat(_ node: Syntax, attributes: AttributeListSyntax) {
        hasPublicAPI = true
        let attributeNames = attributeNames(attributes)
        if attributeNames.contains("_spi") {
            unsafeReasonDiagnostic(.spi, node: node)
        }
        
        let usedMacroNames = attributeNames.first { name in
            macroNames.contains(name) || macroNames.contains(name.split(separator: ".").last.map(String.init) ?? name)
        }
        if usedMacroNames != nil {
            unsafeReasonDiagnostic(.macro, node: node)
        }
    }
    
    private func unsafeReasonDiagnostic(_ reason: UnsafeApiReason, node: Syntax, representation: String? = nil) {
        reasons.insert(reason)
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        var text = representation ?? node.trimmedDescription
        if let brace = text.firstIndex(of: "{") { text = String(text[..<brace]).trimmingCharacters(in: .whitespacesAndNewlines) }
        text = text.replacingOccurrences(of: "\n", with: " ").split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        diagnostics.append(
            UnsafeApiDiagnostic(
                file: path.pathString,
                line: location.line,
                column: location.column,
                reason: reason,
                declaration: text
            )
        )
    }
    
    // MARK: - Visibility Helpers
    
    private func isVisible(_ node: Syntax) -> Bool {
        if let decl = node.asProtocol(WithModifiersSyntax.self), hasVisibleModifier(decl.modifiers) {
            return true
        }
        if let decl = node.asProtocol(WithAttributesSyntax.self), hasUsableFromInline(decl.attributes) {
            return true
        }
        return isVisibleProtocolNode(node)
    }
    
    private func isVisibleProtocolNode(_ node: Syntax) -> Bool {
        var cursor = node.parent
        while let current = cursor{
            if let proto = current.as(ProtocolDeclSyntax.self) {
                return hasVisibleModifier(proto.modifiers) || hasUsableFromInline(proto.attributes)
            }
            if current.is(DeclSyntax.self) {
                return false
            }
            cursor = current.parent
        }
        return false
    }
    
    private func hasVisibleModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        return modifiers.contains { ["public", "open"].contains($0.name.text) }
    }
    
    private func hasUsableFromInline(_ attributes: AttributeListSyntax) -> Bool {
        attributeNames(attributes).contains("usableFromInline")
    }
    
    private func attributeNames(_ attributes: AttributeListSyntax) -> [String] {
        let visitor = AttributeNameVisitor()
        visitor.walk(attributes)
        return visitor.names
    }
    
    private func enclosingVariable(_ node: Syntax) -> VariableDeclSyntax? {
        var cursor = node.parent
        while let current = cursor {
            if let variable = current.as(VariableDeclSyntax.self) { return variable }
            cursor = current.parent
        }
        return nil
    }
    
    private func isInsideVisibleEnum(_ node: Syntax) -> Bool {
        var cursor = node.parent
        while let current = cursor {
            if let decl = current.as(EnumDeclSyntax.self) { return isVisible(Syntax(decl)) }
            cursor = current.parent
        }
        return false
    }
}

private final class AttributeNameVisitor: SyntaxVisitor {
    var names: [String] = []
    
    init() {
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.attributeName.trimmedDescription)
        return .skipChildren
    }
}
