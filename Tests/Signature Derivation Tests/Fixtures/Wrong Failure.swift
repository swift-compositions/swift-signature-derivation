import Either
import Signature_Derivation

enum Greeting {
    struct Name {}
    struct Message {}
    enum Failure: Swift.Error { case refused }

    @Signature
    protocol `Protocol` {
        func greet(_ name: Name) throws(Failure) -> Message
    }
}

enum Counter {
    enum Failure: Swift.Error { case refused }
}

let result: Either<Greeting.Greet.Output, Greeting.Greet.Failure> =
    .right(Counter.Failure.refused)
