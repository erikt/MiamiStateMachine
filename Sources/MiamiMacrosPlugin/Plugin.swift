import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin with the macros of MiamiMacros.
@main
struct MiamiMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        StateMachineEventMacro.self,
    ]
}
