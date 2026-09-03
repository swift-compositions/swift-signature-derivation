import Either
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
    struct Value {}
    enum Failure: Swift.Error {}

    @Signature
    protocol `Protocol` {
        func increment(_ limit: Limit) throws(Failure) -> Value
    }
}

func accept<Index: Operation.Symbol>(
    _: borrowing Operation.Application<Index>,
    result: borrowing Either<Index.Output, Index.Failure>
) {}

let operation = Greeting.Greet.Application(.init())
let result: Either<Counter.Increment.Output, Counter.Increment.Failure> =
    .left(.init())
accept(operation, result: result)
