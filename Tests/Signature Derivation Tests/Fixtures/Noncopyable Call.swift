import Signature_Derivation

enum Linear {
    struct Token: ~Copyable {}

    @Signature
    protocol `Protocol` {
        func consume(_ token: consuming Token)
    }
}

func requireCopyable<Value: Copyable>(_: Value) {}

func prove() {
    requireCopyable(Linear.Call.consume(.init()))
}
