@_exported import Either
@_exported import Operation
@_exported import Optic

@attached(peer, names: arbitrary)
public macro Signature(copyable: Bool = true) = #externalMacro(
    module: "Signature_Derivation_Macros",
    type: "Macro"
)
