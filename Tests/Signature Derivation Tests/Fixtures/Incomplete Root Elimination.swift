import Signature_Derivation

enum Greeting {
    @Signature
    protocol `Protocol` {
        func greet(_ name: String) -> String
    }
}

enum Counter {
    @Signature
    protocol `Protocol` {
        func increment(_ value: Int) -> Int
    }
}

enum Example {
    @Signature
    protocol `Protocol` {
        associatedtype Greeting: Proof::Greeting.`Protocol`
        associatedtype Counter: Proof::Counter.`Protocol`

        var greeting: Greeting { get }
        var counter: Counter { get }
    }
}

let incomplete = Example.Call.Eliminator<String>(
    greeting: { _ in "greeting" }
)
