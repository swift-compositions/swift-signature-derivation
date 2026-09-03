import Signature_Derivation

enum Scoped {
    struct ScopedToken: ~Escapable {}

    @Signature
    protocol `Protocol` {
        func inspect(_ token: consuming ScopedToken)
    }
}

func prove() {
    _ = Scoped.Call.inspect(.init())
}
