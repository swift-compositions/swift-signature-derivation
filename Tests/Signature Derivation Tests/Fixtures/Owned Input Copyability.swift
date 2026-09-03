import Signature_Derivation

enum Owned {
    @Signature
    protocol `Protocol` {
        func consume(_ value: consuming Int)
    }
}

enum Leaf {
    @Signature
    protocol `Protocol` {
        func ping()
    }
}

enum Root {
    @Signature
    protocol `Protocol` {
        associatedtype Leaf: Proof::Leaf.`Protocol`

        var leaf: Leaf { get }
    }
}

func requireCopyable<Value: Copyable>(_: Value) {}

func proveOwnedInputBoundary() {
    requireCopyable(Owned.Call.consume(1))
    requireCopyable(Root.Call.leaf(.ping()))
}
