import Signature_Derivation_Core
import SwiftSyntax
import SwiftSyntaxMacros

public struct Macro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@Signature applies to a protocol declaration only.")
        }
        let owner = context.lexicalContext.first.flatMap { syntax -> TypeSyntax? in
            if let declaration = syntax.as(EnumDeclSyntax.self) {
                return TypeSyntax(IdentifierTypeSyntax(name: declaration.name))
            }
            if let declaration = syntax.as(StructDeclSyntax.self) {
                return TypeSyntax(IdentifierTypeSyntax(name: declaration.name))
            }
            if let declaration = syntax.as(ExtensionDeclSyntax.self) {
                return declaration.extendedType.trimmed
            }
            return nil
        }
        let spelling = declaration.name.text
        let name = spelling.first == "`" && spelling.last == "`"
            ? String(spelling.dropFirst().dropLast())
            : spelling
        guard name == "Protocol", let owner else {
            throw MacroExpansionErrorMessage(
                "@Signature requires a semantic protocol named `Protocol` nested in its domain namespace."
            )
        }
        let signature = Signature(declaration: declaration, owner: owner)
        guard signature.diagnostics.isEmpty else {
            throw MacroExpansionErrorMessage(
                "@Signature cannot derive this finite signature: \(signature.diagnostics.joined(separator: "; "))."
            )
        }
        return Derivation.peers(of: signature)
    }
}
