import Signature_Derivation
import Testing

private enum Greeting {
    struct Name: Equatable {
        var value: String
    }

    struct Message: Equatable {
        var value: String
    }

    @Signature
    protocol `Protocol` {
        func greet(_ name: Name) async -> Message
    }
}

private enum Counter {
    struct Limit {
        var value: Int
    }

    struct Value: Equatable {
        var value: Int
    }

    enum Error: Swift.Error, Equatable {
        case exceeded
    }

    @Signature
    protocol `Protocol` {
        func increment(limit: Limit) async throws(Error) -> Value
    }
}

private enum Example {
    @Signature
    protocol `Protocol` {
        associatedtype Greeting: Signature_Derivation_Tests::Greeting.`Protocol`
        associatedtype Counter: Signature_Derivation_Tests::Counter.`Protocol`

        var greeting: Greeting { get }
        var counter: Counter { get }
    }
}

private enum Nested {
    struct Input {}
    struct Output {}
    enum Failure: Swift.Error {}

    @Signature
    protocol `Protocol` {
        func transform(
            _ values: [Input]
        ) throws(Failure) -> Swift.Result<Output, Failure>
    }
}

private enum Linear {
    struct Token: ~Copyable {
        let value: Int
    }

    @Signature
    protocol `Protocol` {
        func consume(_ token: consuming Token) -> Int
    }
}

private enum LinearExample {
    @Signature
    protocol `Protocol` {
        associatedtype Linear: Signature_Derivation_Tests::Linear.`Protocol`

        var linear: Linear { get }
    }
}

private enum LinearPair {
    struct Token: ~Copyable {
        let value: Int
    }

    @Signature
    protocol `Protocol` {
        func combine(
            _ first: consuming Token,
            with second: consuming Token
        ) -> Int
    }
}

private enum Observation {
    @Signature
    protocol `Protocol` {
        func inspect(_ value: borrowing Int) -> Int
    }
}

private enum Owned {
    @Signature
    protocol `Protocol` {
        func consume(_ value: consuming Int) -> Int
    }
}

private func use<Client: Greeting.`Protocol`>(
    _ client: Client,
    name: Greeting.Name
) async -> Greeting.Message {
    await client.greet(name)
}

private func use<Client: Example.`Protocol`>(
    _ client: Client,
    name: Greeting.Name,
    limit: Counter.Limit
) async throws(Counter.Error) -> (Greeting.Message, Counter.Value) {
    let message = await client.greeting.greet(name)
    let value = try await client.counter.increment(limit: limit)
    return (message, value)
}

private func success<Index: Operation.Symbol>(
    _: borrowing Operation.Application<Index>,
    _ output: consuming Index.Output
) -> Either<Index.Output, Index.Failure> {
    .left(output)
}

private func requireEscapable<Value: ~Copyable & Escapable>(_: consuming Value) {}
private func requireCopyable<Value: Copyable>(_: Value) {}

@Suite
private struct `Domain Tests` {
    let greeting = Greeting.Product(
        greet: { .init(value: "Hello, \($0.value)!") }
    )
    let counter = Counter.Product(
        increment: { limit throws(Counter.Error) in
            guard limit.value < 10 else { throw .exceeded }
            return .init(value: limit.value + 1)
        }
    )

    @Test
    func `operation application carries its input and dependent result family`() {
        let operation = Greeting.Greet.Application(
            Greeting.Name(value: "Blob")
        )
        let result = success(
            operation,
            Greeting.Message(value: "Hello, Blob!")
        )

        #expect(operation.input == .init(value: "Blob"))
        switch result {
        case let .left(message):
            #expect(message == .init(value: "Hello, Blob!"))
        case .right:
            Issue.record("Never is uninhabited")
        }
    }

    @Test
    func `call directly stores its operation leaf and eliminates exhaustively`() {
        let call = Greeting.Call.greet(.init(value: "Blob"))
        let eliminate = Greeting.Call.Eliminator<Greeting.Name>(
            greet: { $0.input }
        )
        let name = eliminate(call)

        #expect(name == .init(value: "Blob"))
    }

    @Test
    func `call receives canonical coproduct prisms`() {
        let call = Greeting.Call.greet(.init(value: "Blob"))

        switch Greeting.Call.prisms.greet.match(call) {
        case let .right(application):
            #expect(application.input == .init(value: "Blob"))
        case .left:
            Issue.record("Expected the greet prism to match")
        }
    }

    @Test
    func `call carries a noncopyable input through elimination and a prism`() {
        let eliminate = Linear.Call.Eliminator<Int>(
            consume: { $0.input.value }
        )
        let eliminated = Linear.Call.consume(.init(value: 41))

        #expect(eliminate(eliminated) == 41)

        let matched = Linear.Call.prisms.consume.match(
            .consume(.init(value: 42))
        )
        switch consume matched {
        case let .right(application):
            #expect(application.input.value == 42)
        case .left:
            Issue.record("Expected the consuming call prism to match")
        }
        requireEscapable(Linear.Call.consume(.init(value: 43)))
    }

    @Test
    func `composed call carries a noncopyable child call`() {
        let eliminateChild = Linear.Call.Eliminator<Int>(
            consume: { $0.input.value }
        )
        let eliminateRoot = LinearExample.Call.Eliminator<Int>(
            linear: { eliminateChild($0) }
        )
        let call = LinearExample.Call.linear(
            .consume(.init(value: 44))
        )

        #expect(eliminateRoot(call) == 44)

        let matched = LinearExample.Call.prisms.linear.match(
            .linear(.consume(.init(value: 45)))
        )
        switch consume matched {
        case let .right(child):
            #expect(eliminateChild(child) == 45)
        case .left:
            Issue.record("Expected the composed call prism to match")
        }
        requireEscapable(
            LinearExample.Call.linear(.consume(.init(value: 46)))
        )
    }

    @Test
    func `call carries a noncopyable tuple input`() {
        let eliminate = LinearPair.Call.Eliminator<Int>(
            combine: { _ in 42 }
        )
        let call = LinearPair.Call.combine(
            .init(value: 20),
            with: .init(value: 22)
        )

        #expect(eliminate(call) == 42)
    }

    @Test
    func `an owned copyable input keeps its call copyable`() {
        let call = Owned.Call.consume(7)
        let eliminate = Owned.Call.Eliminator<Int>(
            consume: { $0.input }
        )
        requireCopyable(call)

        #expect(eliminate(call) == 7)
    }

    @Test
    func `call snapshots a borrowed copyable input`() {
        let call = Observation.Call.inspect(42)
        let copy = call
        let eliminate = Observation.Call.Eliminator<Int>(
            inspect: { $0.input }
        )

        #expect(eliminate(copy) == 42)
        #expect(eliminate(call) == 42)
    }

    @Test
    func `nested domain types remain qualified throughout syntax trees`() {
        let application = Nested.Transform.Application([.init()])
        let _: Nested.Transform.Input = application.input
        let _: Nested.Transform.Output.Type = Swift.Result<
            Nested.Output,
            Nested.Failure
        >.self
        let _: Nested.Transform.Failure.Type = Nested.Failure.self
    }

    @Test
    func `generated product is the semantic client interpretation`() async {
        let message = await use(greeting, name: .init(value: "Blob"))
        let _: any Greeting.`Protocol` = greeting

        #expect(message == .init(value: "Hello, Blob!"))
    }

    @Test
    func `root signature composes child algebras and child calls`() async throws {
        let client = Example.Product(greeting: greeting, counter: counter)
        let values = try await use(
            client,
            name: .init(value: "Blob"),
            limit: .init(value: 2)
        )
        let call = Example.Call.greeting(.greet(.init(value: "Blob")))
        let eliminateGreeting = Greeting.Call.Eliminator<Greeting.Name>(
            greet: { $0.input }
        )
        let eliminate = Example.Call.Eliminator<Greeting.Name>(
            greeting: { eliminateGreeting($0) },
            counter: { _ in Greeting.Name(value: "counter") }
        )
        let name = eliminate(call)
        requireCopyable(call)

        #expect(values.0 == .init(value: "Hello, Blob!"))
        #expect(values.1 == .init(value: 3))
        #expect(name == .init(value: "Blob"))
    }

    @Test
    func `ordinary calls preserve labels and effects`() async throws {
        let client = Example.Product(greeting: greeting, counter: counter)
        let call = Counter.Call.increment(limit: .init(value: 2))
        let eliminate = Counter.Call.Eliminator<Counter.Limit>(
            increment: { $0.input }
        )
        let limit = eliminate(call)
        let message = await client.greeting.greet(.init(value: "Blob"))
        let value = try await client.counter.increment(limit: .init(value: 2))

        #expect(limit.value == 2)
        #expect(message == .init(value: "Hello, Blob!"))
        #expect(value == .init(value: 3))
        await #expect(throws: Counter.Error.exceeded) {
            try await client.counter.increment(limit: .init(value: 10))
        }
    }
}
