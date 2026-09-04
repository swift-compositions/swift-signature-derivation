@_exported import Checkpoint
@_exported import Coder
@_exported import Either
@_exported import Operation
@_exported import Optic
@_exported import Parser
@_exported import Serializer

@attached(peer, names: arbitrary)
public macro Signature() = #externalMacro(
    module: "Signature_Derivation_Macros",
    type: "Macro"
)

@attached(extension, conformances: Copyable)
public macro Structural() = #externalMacro(
    module: "Signature_Derivation_Macros",
    type: "Structural"
)
