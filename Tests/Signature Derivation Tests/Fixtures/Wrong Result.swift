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
    result: borrowing Either<Index.Failure, Index.Output>
) {}

let operation = Greeting.Operations.Greet.Application(.init())
let result: Either<Counter.Operations.Increment.Failure, Counter.Operations.Increment.Output> =
    .right(.init())
accept(operation, result: result)
