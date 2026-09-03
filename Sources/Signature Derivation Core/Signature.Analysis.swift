public import SwiftSyntax
public import Product_Derivation_Core
import SwiftSyntaxBuilder

extension Signature {
    public struct Analysis {
        public struct Coordinate {
            public struct Input {
                public let parameter: Product.Analysis.Parameter
                public let label: TokenSyntax
                public let type: TypeSyntax
                public let expression: ExprSyntax
            }

            public let function: Product.Analysis.Function
            public let symbol: TokenSyntax
            public let inputs: [Input]
            public let input: TypeSyntax
            public let inputExpression: ExprSyntax
            public let output: TypeSyntax
            public let failure: TypeSyntax

            public var declaration: FunctionDeclSyntax { function.declaration }
            public var name: TokenSyntax { function.name }

            fileprivate init(
                _ function: Product.Analysis.Function,
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
        public let product: Product.Analysis
        public let coordinates: [Coordinate]
        public let children: [Child]
        public let declaresNoncopyableCall: Bool
        public let diagnostics: [String]

        public init(
            declaration: ProtocolDeclSyntax,
            owner: TypeSyntax
        ) {
            self.declaration = declaration
            self.owner = owner
            declaresNoncopyableCall = declaration.attributes.contains { attribute in
                guard
                    let attribute = attribute.as(AttributeSyntax.self),
                    attribute.attributeName.trimmedDescription == "Signature",
                    let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
                else { return false }
                return arguments.contains { argument in
                    argument.label?.text == "copyable"
                        && argument.expression.as(BooleanLiteralExprSyntax.self)?
                            .literal.tokenKind == .keyword(.false)
                }
            }
            let product = Product.Analysis(declaration)
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
            of associated: Product.Analysis.AssociatedType
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
