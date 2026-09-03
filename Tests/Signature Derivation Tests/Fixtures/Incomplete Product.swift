import Signature_Derivation

enum Fixture {
    @Signature
    protocol `Protocol` {
        func first(_ value: Int) -> String
        func second(_ value: Bool) -> Int
    }
}

let product = Fixture.Product(first: { String($0) })
