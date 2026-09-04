import Either
import Signature_Derivation

enum Greeting {
    struct Name {}
    struct Message {}
    enum Failure: Swift.Error {}

    @Signature
    protocol `Protocol` {
        func greet(_ name: Name) throws(Failure) -> Message
    }
}

enum Counter {
    struct Value {}
}

let result: Either<Greeting.Operations.Greet.Failure, Greeting.Operations.Greet.Output> =
    .right(Counter.Value())
