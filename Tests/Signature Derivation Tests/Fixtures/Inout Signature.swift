import Signature_Derivation

enum Mutation {
    @Signature
    protocol `Protocol` {
        func mutate(_ value: inout Int)
    }
}
