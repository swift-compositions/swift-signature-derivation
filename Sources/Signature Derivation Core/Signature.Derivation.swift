public import SwiftSyntax
import Coproduct_Derivation_Core
import Eliminator_Derivation_Core
import Fold_Derivation_Core
import Prism_Derivation_Core
import Product_Derivation_Core
import SwiftSyntaxBuilder

extension Signature {
    public enum Derivation {
        public static func peers(of signature: Signature.Analysis) -> [DeclSyntax] {
            let access = signature.product.access
            let spelling = access.map { "\($0.name.text) " } ?? ""
            return Product.Derivation.peers(of: signature.product)
                + operations(of: signature, access: spelling)
                + call(of: signature, access: access)
        }

        private static func operations(
            of signature: Signature.Analysis,
            access: String
        ) -> [DeclSyntax] {
            guard !signature.coordinates.isEmpty else { return [] }
            let symbols = signature.coordinates.map {
                symbol($0, access: access)
            }.joined(separator: "\n\n")
            return [DeclSyntax(stringLiteral: """
                \(access)enum Operations {
                \(symbols)
                }
                """)]
        }

        private static func symbol(
            _ coordinate: Signature.Analysis.Coordinate,
            access: String
        ) -> String {
            """
                \(access)enum \(coordinate.symbol.trimmedDescription): Operation::Operation.Member {
                    \(access)typealias Input = \(coordinate.input.trimmedDescription)
                    \(access)typealias Output = \(coordinate.output.trimmedDescription)
                    \(access)typealias Failure = \(coordinate.failure.trimmedDescription)
                    \(access)typealias Application = Operation::Operation.Application<
                        Self
                    >
                    \(access)typealias Coproduct = Call
                    \(access)typealias Case = Optic<Call, Call, Application, Application>.Case
                    \(access)static var keyPath: KeyPath<Call.Cases, Case> {
                        \\.\(coordinate.name.text)
                    }
                }
                """
        }

        private static func call(
            of signature: Signature.Analysis,
            access: DeclModifierSyntax?
        ) -> [DeclSyntax] {
            let accessSpelling = access.map { "\($0.name.text) " } ?? ""
            // The coproduct is generic in its summands so that the compiler, not a
            // syntax macro, decides whether a Call is Copyable: @Structural adds
            // `Copyable` exactly when every summand is. Leaves bind the parameter to
            // the operation's Application, children to the child's Call.
            //
            // Call remains Escapable because its canonical generated prisms return
            // both Call and Application from stored escaping arrows. Swift 6.4
            // cannot express those result lifetime dependencies; the focused Optic
            // and Signature compiler fixtures lock down that boundary.
            let owner = signature.owner.trimmedDescription
            let leaves = signature.coordinates.map { coordinate in
                (
                    parameter: "\(coordinate.symbol.text)Application",
                    name: coordinate.name,
                    bound: "\(owner).Operations.\(coordinate.symbol.trimmedDescription).Application"
                )
            }
            let children = signature.children.map { child in
                let name = child.name.text
                return (
                    parameter: "\(name.prefix(1).uppercased())\(name.dropFirst())Call",
                    name: child.name,
                    bound: child.call.trimmedDescription
                )
            }
            let summands = leaves + children
            let parameters = summands.map { "\($0.parameter): ~Copyable" }
                .joined(separator: ", ")
            let arguments = summands.map(\.bound).joined(separator: ", ")
            let cases = summands.map { summand in
                EnumCaseElementSyntax(
                    name: summand.name,
                    parameterClause: EnumCaseParameterClauseSyntax(
                        parameters: EnumCaseParameterListSyntax([
                            EnumCaseParameterSyntax(
                                type: TypeSyntax(
                                    IdentifierTypeSyntax(name: .identifier(summand.parameter))
                                )
                            )
                        ])
                    )
                )
            }
            let caseDeclarations = cases.map {
                "case \($0.trimmedDescription)"
            }.joined(separator: "\n")
            let constructors = zip(signature.coordinates, leaves).map { coordinate, leaf in
                """
                    \(accessSpelling)static func \(coordinate.name.text)\(coordinate.declaration.signature.parameterClause.trimmedDescription) -> Self
                    where \(leaf.parameter) == \(leaf.bound) {
                        let application: \(leaf.bound) = .init(
                            \(coordinate.inputExpression.trimmedDescription)
                        )
                        return Self.\(coordinate.name.text)(application)
                    }
                    """
            }.joined(separator: "\n")

            let coproduct = Coproduct.Analysis(
                whole: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Coproduct"))),
                access: access,
                cases: cases,
                genericParameter: nil,
                isCopyableSuppressed: true
            )
            let algebra = Prism.Derivation.expansion(coproduct)
                + Fold.Derivation.expansion(coproduct)
                + Eliminator.Derivation.expansion(coproduct)
            let members = algebra.map {
                $0.trimmedDescription
            }.joined(separator: "\n\n")
            let caseProperties = summands.map { summand in
                """
                    \(accessSpelling)var \(summand.name.text): Optic<Coproduct, Coproduct, \(summand.parameter), \(summand.parameter)>.Case {
                        .init(prism: Coproduct.prisms.\(summand.name.text), fold: Coproduct.folds.\(summand.name.text))
                    }
                    """
            }.joined(separator: "\n")
            let caseNamespace = """
                \(accessSpelling)struct Cases {
                \(caseProperties)
                }

                \(accessSpelling)static var cases: Cases {
                    Cases()
                }
                """
            let indices = signature.coordinates.map {
                "\(owner).Operations.\($0.symbol.trimmedDescription)"
            } + children.map(\.parameter)
            let operations = indices.dropFirst().reduce(indices[0]) { partial, next in
                "Either<\(partial), \(next)>"
            }
            let router = self.router(
                summands: summands.map {
                    (label: $0.name.text, payload: $0.parameter)
                },
                access: accessSpelling
            )

            return [
                DeclSyntax(stringLiteral: """
                    @Structural
                    \(accessSpelling)enum Coproduct<\(parameters)>: ~Copyable, Operation::Operation.Coproduct {
                    \(accessSpelling)typealias Operations = \(operations)

                    \(caseDeclarations)

                    \(constructors)

                    \(members)

                    \(caseNamespace)

                    \(router)
                    }
                    """),
                DeclSyntax(stringLiteral: """
                    \(accessSpelling)typealias Call = Coproduct<\(arguments)>
                    """),
            ]
        }

        private static func router(
            summands: [(label: String, payload: String)],
            access: String
        ) -> String {
            let output = "Coproduct<\(summands.map(\.payload).joined(separator: ", "))>"
            let coders = summands.map { summand in
                (
                    label: summand.label,
                    payload: summand.payload,
                    coder: "\(summand.label.prefix(1).uppercased())\(summand.label.dropFirst())Coder"
                )
            }
            let parameters = (
                ["Message: Checkpoint::Restorable", "Failure: Swift.Error & Swift.Equatable"]
                    + coders.map {
                        "\($0.coder): Coder::Coding<Message, \($0.payload), Message, Failure>"
                    }
            ).joined(separator: ",\n")
            let storage = coders.map {
                "\(access)let \($0.label): \($0.coder)"
            }.joined(separator: "\n")
            let initializerParameters = (
                ["absent: Failure"] + coders.map { "\($0.label): \($0.coder)" }
            ).joined(separator: ",\n")
            let assignments = (["self.absent = absent"] + coders.map {
                "self.\($0.label) = \($0.label)"
            }).joined(separator: "\n")
            let parsed = coders.map { coder in
                """
                do throws(Failure) {
                    return Output.\(coder.label)(try \(coder.label).parse(&input))
                } catch {
                    guard error == absent else { throw error }
                    input.seek(to: mark)
                }
                """
            }.joined(separator: "\n")
            let serialized = coders.map { coder in
                """
                if Output.folds.\(coder.label)(output, { payload in
                    do throws(Failure) {
                        try router.\(coder.label).serialize(payload, into: &buffer)
                    } catch {
                        failure = error
                    }
                }) {
                    if let failure { throw failure }
                    return
                }
                """
            }.joined(separator: "\n\n")

            return """
                \(access)struct Router<
                \(parameters)
                >: Coder::Coding {
                    \(access)typealias Input = Message

                    \(access)typealias Buffer = Message

                    \(access)typealias Output = \(output)

                    \(access)let absent: Failure

                    \(storage)

                    \(access)init(
                    \(initializerParameters)
                    ) {
                        \(assignments)
                    }

                    \(access)borrowing func parse(_ input: inout Message) throws(Failure) -> Output {
                        let mark = input.checkpoint
                        \(parsed)
                        throw absent
                    }

                    \(access)borrowing func serialize(
                        _ output: borrowing Output,
                        into buffer: inout Message
                    ) throws(Failure) {
                        let router = copy self
                        var failure: Failure?

                        \(serialized)

                        throw absent
                    }
                }
                """
        }
    }
}
