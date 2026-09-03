public import SwiftSyntax
import Coproduct_Derivation_Core
import Eliminator_Derivation_Core
import Prism_Derivation_Core
public import Product_Derivation_Core
import SwiftSyntaxBuilder

extension Signature {
    public enum Derivation {
        public static func peers(of signature: Signature.Analysis) -> [DeclSyntax] {
            let access = signature.product.access
            let spelling = access.map { "\($0.name.text) " } ?? ""
            return Product.Derivation.peers(of: signature.product)
                + signature.coordinates.map { symbol($0, access: spelling) }
                + [call(of: signature, access: access)]
        }

        private static func symbol(
            _ coordinate: Signature.Analysis.Coordinate,
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
            of signature: Signature.Analysis,
            access: DeclModifierSyntax?
        ) -> DeclSyntax {
            let accessSpelling = access.map { "\($0.name.text) " } ?? ""
            let suppressesCopyable = signature.declaresNoncopyableCall
                || signature.coordinates.contains { coordinate in
                    coordinate.function.parameters.contains {
                        $0.transfersOwnership
                    }
                }
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

            let coproduct = Coproduct.Analysis(
                whole: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Call"))),
                access: access,
                cases: cases,
                genericParameter: nil,
                isCopyableSuppressed: suppressesCopyable
            )
            let algebra = Prism.Derivation.expansion(coproduct)
                + Eliminator.Derivation.expansion(coproduct)
            let members = algebra.map {
                $0.trimmedDescription
            }.joined(separator: "\n\n")
            let indices = signature.coordinates.map { $0.symbol.trimmedDescription }
                + signature.children.map { $0.call.trimmedDescription }
            let operations = indices.dropFirst().reduce(indices[0]) { partial, next in
                "Either<\(partial), \(next)>"
            }
            let conformance = suppressesCopyable
                ? ": ~Copyable, Operation::Operation.Coproduct"
                : ": Operation::Operation.Coproduct"

            return DeclSyntax(stringLiteral: """
                \(accessSpelling)enum Call\(conformance) {
                \(accessSpelling)typealias Operations = \(operations)

                \(caseDeclarations)

                \(constructors)

                \(members)
                }
                """)
        }

    }
}
