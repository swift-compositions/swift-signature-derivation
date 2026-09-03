public import SwiftSyntax
import Coproduct_Derivation_Core
import Eliminator_Derivation_Core
import Prism_Derivation_Core
public import Product_Derivation_Core
import SwiftSyntaxBuilder

public struct Signature {
    public struct Coordinate {
        public struct Input {
            public let parameter: Product_Derivation_Core.Derivation.Analysis.Parameter
            public let label: TokenSyntax
            public let type: TypeSyntax
            public let expression: ExprSyntax
        }

        public let function: Product_Derivation_Core.Derivation.Analysis.Function
        public let symbol: TokenSyntax
        public let inputs: [Input]
        public let input: TypeSyntax
        public let inputExpression: ExprSyntax
        public let output: TypeSyntax
        public let failure: TypeSyntax

        public var declaration: FunctionDeclSyntax { function.declaration }
        public var name: TokenSyntax { function.name }

        fileprivate init(
            _ function: Product_Derivation_Core.Derivation.Analysis.Function,
            owner: TypeSyntax
        ) {
            self.function = function
            symbol = .identifier(Self.symbolName(function.name.text))
            let qualify = DomainQualifier(
                owner: owner,
                names: ["Input", "Output", "Failure"]
            )
            inputs = function.parameters.map { parameter in
                let declaration = parameter.declaration
                let source = declaration.firstName.tokenKind == .wildcard
                    ? parameter.localName
                    : declaration.firstName
                return Input(
                    parameter: parameter,
                    label: .identifier(source.text),
                    type: qualify.rewrite(parameter.valueType),
                    expression: parameter.ownedExpression
                )
            }
            input = Self.input(of: inputs)
            inputExpression = Self.inputExpression(of: inputs)
            output = qualify.rewrite(function.output)
            failure = qualify.rewrite(
                function.thrownError
                    ?? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Never")))
            )
        }

        private static func input(
            of inputs: [Input]
        ) -> TypeSyntax {
            switch inputs.count {
            case 0:
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
            case 1:
                return inputs[inputs.startIndex].type
            default:
                let elements = inputs.enumerated().map { offset, input in
                    return TupleTypeElementSyntax(
                        firstName: input.label,
                        colon: .colonToken(trailingTrivia: .space),
                        type: input.type,
                        trailingComma: offset == inputs.count - 1
                            ? nil
                            : .commaToken(trailingTrivia: .space)
                    )
                }
                return TypeSyntax(
                    TupleTypeSyntax(elements: TupleTypeElementListSyntax(elements))
                )
            }
        }

        private static func inputExpression(
            of inputs: [Input]
        ) -> ExprSyntax {
            switch inputs.count {
            case 0:
                return ExprSyntax(
                    TupleExprSyntax(elements: LabeledExprListSyntax([]))
                )
            case 1:
                return inputs[0].expression
            default:
                let elements = inputs.enumerated().map { offset, input in
                    LabeledExprSyntax(
                        label: input.label,
                        colon: .colonToken(trailingTrivia: .space),
                        expression: input.expression,
                        trailingComma: offset == inputs.count - 1
                            ? nil
                            : .commaToken(trailingTrivia: .space)
                    )
                }
                return ExprSyntax(
                    TupleExprSyntax(
                        elements: LabeledExprListSyntax(elements)
                    )
                )
            }
        }

        private static func symbolName(_ operation: String) -> String {
            guard let first = operation.first else { return operation }
            return String(first).uppercased() + String(operation.dropFirst())
        }
    }

    public struct Child {
        public let declaration: VariableDeclSyntax
        public let name: TokenSyntax
        public let domain: TypeSyntax

        public var call: TypeSyntax {
            TypeSyntax(MemberTypeSyntax(baseType: domain, name: .identifier("Call")))
        }
    }

    public let declaration: ProtocolDeclSyntax
    public let owner: TypeSyntax
    public let product: Product_Derivation_Core.Derivation.Analysis
    public let coordinates: [Coordinate]
    public let children: [Child]
    public let diagnostics: [String]

    public init(
        declaration: ProtocolDeclSyntax,
        owner: TypeSyntax
    ) {
        self.declaration = declaration
        self.owner = owner
        let product = Product_Derivation_Core.Derivation.Analysis(declaration)
        self.product = product
        coordinates = product.functionCoordinates.map { Coordinate($0, owner: owner) }

        var reasons = product.diagnostics
        if declaration.inheritanceClause != nil {
            reasons.append("inherited protocols are not a closed finite signature")
        }
        for function in product.functionCoordinates where function.isUntypedThrows {
            reasons.append(
                "`\(function.name.text)` has untyped throws; its failure sort must be explicit"
            )
        }
        for function in product.functionCoordinates {
            for parameter in function.parameters where parameter.isInout {
                reasons.append(
                    "`\(function.name.text)` has an inout parameter; a signature Call is an owned snapshot, not a state transition"
                )
            }
        }

        var domains: [String: TypeSyntax] = [:]
        for coordinate in product.associatedTypeCoordinates {
            guard let domain = Self.domain(of: coordinate) else {
                reasons.append(
                    "`\(coordinate.declaration.trimmedDescription)` does not name a child semantic protocol"
                )
                continue
            }
            domains[coordinate.name.text] = domain
        }

        var usedDomains: Set<String> = []
        var recognizedChildren: [Child] = []
        for property in product.propertyCoordinates {
            guard
                let associated = property.type.as(IdentifierTypeSyntax.self),
                associated.moduleSelector == nil,
                associated.genericArgumentClause == nil,
                let domain = domains[associated.name.text]
            else {
                reasons.append(
                    "`\(property.declaration.trimmedDescription)` does not expose a declared child signature"
                )
                continue
            }
            usedDomains.insert(associated.name.text)
            recognizedChildren.append(
                Child(
                    declaration: property.declaration,
                    name: property.name,
                    domain: domain
                )
            )
        }
        for coordinate in product.associatedTypeCoordinates
        where !usedDomains.contains(coordinate.name.text) {
            reasons.append("`\(coordinate.name.text)` has no getter coordinate")
        }
        children = recognizedChildren
        diagnostics = reasons
    }

    fileprivate static func domain(
        of associated: Product_Derivation_Core.Derivation.Analysis.AssociatedType
    ) -> TypeSyntax? {
        guard
            associated.declaration.inheritanceClause?.inheritedTypes.count == 1,
            let inherited = associated.constraint,
            let semantic = inherited.as(MemberTypeSyntax.self),
            ["Protocol", "`Protocol`"].contains(semantic.name.text),
            semantic.genericArgumentClause == nil
        else { return nil }
        return semantic.baseType
    }
}

public enum Derivation {
    public static func peers(of signature: Signature) -> [DeclSyntax] {
        let access = signature.product.access
        let spelling = access.map { "\($0.name.text) " } ?? ""
        return Product_Derivation_Core.Derivation.peers(of: signature.product)
            + signature.coordinates.map { symbol($0, access: spelling) }
            + [call(of: signature, access: access)]
    }

    private static func symbol(
        _ coordinate: Signature.Coordinate,
        access: String
    ) -> DeclSyntax {
        DeclSyntax(stringLiteral: """
            \(access)enum \(coordinate.symbol.trimmedDescription): Operation.Symbol {
                \(access)typealias Input = \(coordinate.input.trimmedDescription)
                \(access)typealias Output = \(coordinate.output.trimmedDescription)
                \(access)typealias Failure = \(coordinate.failure.trimmedDescription)
                \(access)typealias Application = Operation::Operation.Application<
                    Self
                >
            }
            """)
    }

    private static func call(
        of signature: Signature,
        access: DeclModifierSyntax?
    ) -> DeclSyntax {
        let accessSpelling = access.map { "\($0.name.text) " } ?? ""
        // An owned parameter can carry a noncopyable value, and a child Call's
        // capability is unavailable to a syntax macro. Because @Signature is
        // nested, its peer expansion also cannot introduce the file-scope
        // constrained extension required by a generic backing enum's
        // conditional Copyable conformance. These cases therefore take a
        // conservative path. Plain leaf signatures retain compiler-synthesized
        // Copyable; an owned copyable payload or fully copyable child can lose
        // that capability until nested conditional conformances are expressible.
        //
        // Call remains Escapable because its canonical generated prisms return
        // both Call and Application from stored escaping arrows. Swift 6.4
        // cannot express those result lifetime dependencies; the focused Optic
        // and Signature compiler fixtures lock down that boundary.
        let suppressesCopyable = !signature.children.isEmpty
            || signature.coordinates.contains { coordinate in
                coordinate.function.parameters.contains {
                    $0.transfersOwnership
                }
            }
        let capability = suppressesCopyable ? ": ~Copyable" : ""
        let leafCases = signature.coordinates.map { coordinate in
            EnumCaseElementSyntax(
                name: coordinate.name,
                parameterClause: EnumCaseParameterClauseSyntax(
                    parameters: EnumCaseParameterListSyntax([
                        EnumCaseParameterSyntax(
                            type: TypeSyntax(
                                MemberTypeSyntax(
                                    baseType: TypeSyntax(
                                        IdentifierTypeSyntax(name: coordinate.symbol)
                                    ),
                                    name: .identifier("Application")
                                )
                            )
                        )
                    ])
                )
            )
        }
        let childCases = signature.children.map { child in
            EnumCaseElementSyntax(
                name: child.name,
                parameterClause: EnumCaseParameterClauseSyntax(
                    parameters: EnumCaseParameterListSyntax([
                        EnumCaseParameterSyntax(type: child.call)
                    ])
                )
            )
        }
        let cases = leafCases + childCases
        let caseDeclarations = cases.map {
            "case \($0.trimmedDescription)"
        }.joined(separator: "\n")
        let constructors = signature.coordinates.map { coordinate in
            """
                \(accessSpelling)static func \(coordinate.name.text)\(coordinate.declaration.signature.parameterClause.trimmedDescription) -> Self {
                    let application: \(coordinate.symbol.trimmedDescription).Application = .init(
                        \(coordinate.inputExpression.trimmedDescription)
                    )
                    return Self.\(coordinate.name.text)(application)
                }
                """
        }.joined(separator: "\n")

        let coproduct = Coproduct_Derivation_Core.Analysis(
            whole: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Call"))),
            access: access,
            cases: cases,
            genericParameter: nil,
            isCopyableSuppressed: suppressesCopyable
        )
        let algebra = Prism_Derivation_Core.Derivation.expansion(coproduct)
            + Eliminator_Derivation_Core.Derivation.expansion(coproduct)
        let members = algebra.map {
            $0.trimmedDescription
        }.joined(separator: "\n\n")

        return DeclSyntax(stringLiteral: """
            \(accessSpelling)enum Call\(capability) {
            \(caseDeclarations)

            \(constructors)

            \(members)
            }
            """)
    }

}

private final class DomainQualifier: SyntaxRewriter {
    let owner: TypeSyntax
    let names: Set<String>

    init(owner: TypeSyntax, names: Set<String>) {
        self.owner = owner
        self.names = names
    }

    func rewrite(_ type: TypeSyntax) -> TypeSyntax {
        TypeSyntax(visit(type))
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        guard
            node.moduleSelector == nil,
            node.genericArgumentClause == nil,
            names.contains(node.name.text)
        else { return super.visit(node) }
        return TypeSyntax(
            MemberTypeSyntax(
                baseType: owner.trimmed,
                name: .identifier(node.name.text)
            )
        )
    }
}
