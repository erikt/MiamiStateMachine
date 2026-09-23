import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The macro `@StateMachineEvent`. It writes the triggers of an enumeration of
/// events, and the conformance to `StateMachineEvent`.
public struct StateMachineEventMacro: MemberMacro, ExtensionMacro {

    // MARK: - Members

    /// Writes the enumeration `EventTrigger` and the property `eventTrigger`.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let events = try enumeration(of: declaration, at: node)
        let access = accessLevel(of: events)
        let cases = caseNames(of: events)

        // A line for the cases, and one for every case of the mapping. Events
        // without cases get no lines at all, and not an empty one.
        let triggerLines = cases.isEmpty ? [] : ["case \(cases.joined(separator: ", "))"]
        let mappingLines = cases.map { "case .\($0): .\($0)" }

        return [
            DeclSyntax(stringLiteral: (["\(access)enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {"]
                + triggerLines + ["}"]).joined(separator: "\n")),
            DeclSyntax(stringLiteral: (["\(access)var eventTrigger: EventTrigger {", "switch self {"]
                + mappingLines + ["}", "}"]).joined(separator: "\n")),
        ]
    }

    // MARK: - Conformance

    /// Writes the conformance to `StateMachineEvent`, unless the events already have it.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self), !protocols.isEmpty else {
            return []
        }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): MiamiStateMachine.StateMachineEvent {}")]
    }

    // MARK: - Private methods

    /// The enumeration the macro is attached to.
    /// - Throws: A diagnostic if it is not an enumeration, or already has what the macro writes.
    private static func enumeration(of declaration: some DeclGroupSyntax, at node: AttributeSyntax) throws -> EnumDeclSyntax {
        guard let events = declaration.as(EnumDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [Diagnostic(node: node, message: StateMachineEventDiagnostic.notAnEnumeration)])
        }

        for member in events.memberBlock.members {
            let decl = member.decl
            let declaresTrigger = decl.as(EnumDeclSyntax.self)?.name.text == "EventTrigger"
                || decl.as(StructDeclSyntax.self)?.name.text == "EventTrigger"
                || decl.as(TypeAliasDeclSyntax.self)?.name.text == "EventTrigger"
                || decl.as(VariableDeclSyntax.self)?.bindings.contains {
                    $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "eventTrigger"
                } == true
            if declaresTrigger {
                throw DiagnosticsError(diagnostics: [Diagnostic(node: decl, message: StateMachineEventDiagnostic.alreadyDeclared)])
            }
        }

        return events
    }

    /// The names of the cases of an enumeration, in the order they are declared.
    private static func caseNames(of events: EnumDeclSyntax) -> [String] {
        return events.memberBlock.members
            .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
            .flatMap { $0.elements.map(\.name.text) }
    }

    /// The access level to write, with a space after it: the one of the
    /// enumeration if it is public or package, and none otherwise, which
    /// gives the members the access level of the enumeration.
    private static func accessLevel(of events: EnumDeclSyntax) -> String {
        for modifier in events.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return "public "
            case .keyword(.package):
                return "package "
            default:
                continue
            }
        }
        return ""
    }
}

/// What can be wrong where `@StateMachineEvent` is used.
enum StateMachineEventDiagnostic: String, DiagnosticMessage {
    case notAnEnumeration
    case alreadyDeclared

    var message: String {
        switch self {
        case .notAnEnumeration:
            "@StateMachineEvent can only be attached to an enumeration of events"
        case .alreadyDeclared:
            "@StateMachineEvent writes EventTrigger and eventTrigger, which are already declared here"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "MiamiMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity {
        .error
    }
}
