import Signature_Derivation

enum Greeting {
    struct Name {}
    struct Message {}

    @Signature
    protocol `Protocol` {
        func greet(_ name: Name) -> Message
    }
}

enum Counter {
    struct Limit {}
}

let application: Greeting.Operations.Greet.Application = .init(Counter.Limit())
