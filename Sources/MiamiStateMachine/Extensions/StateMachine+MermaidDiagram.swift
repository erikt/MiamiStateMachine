// MARK: - Diagram for Mermaid

extension StateMachine {

    /// The definition of the state machine as a diagram, in the language of
    /// Mermaid. It is drawn where Mermaid is, like in Markdown on GitHub, when
    /// put in a code block marked `mermaid`.
    ///
    /// Every state is declared with its description, and with an identifier
    /// made up from its position among the states, like `state1`. A description
    /// can be any text, which an identifier in Mermaid cannot. The states
    /// connected by transitions are connected by an arrow, labeled with the
    /// events. If several events lead from a state to the same state, they
    /// share one arrow. The initial state has an arrow leading to it from the
    /// start, written `[*]`, and every ending state has an arrow to the end.
    ///
    /// The diagram is the same every time, whatever order the transitions were
    /// given in, so it can be compared with a saved diagram. This needs the
    /// states to have different descriptions. States with the same description
    /// are still different states in the diagram, but which of them that gets
    /// which identifier can differ.
    /// - Complexity: O(*n* log *n*), where *n* is the number of transitions.
    public nonisolated var mermaidDiagram: String {
        return mermaidDiagram(marking: nil)
    }

    /// The state machine as a diagram in the language of Mermaid, like
    /// `mermaidDiagram`, with the current state marked by being filled with
    /// color. It is given a style, named `current`.
    ///
    /// The diagram is of one moment. The state machine may have moved on
    /// when the diagram is drawn.
    /// - Complexity: O(*n* log *n*), where *n* is the number of transitions.
    public var mermaidDiagramWithCurrentState: String {
        return mermaidDiagram(marking: state)
    }

    /// The definition of the state machine as a diagram in the language of
    /// Mermaid, with a state marked.
    /// - Parameter markedState: The state to mark. Nothing is marked if nil.
    /// - Returns: The diagram.
    private nonisolated func mermaidDiagram(marking markedState: State?) -> String {
        let outline = diagramOutline(marking: markedState)

        func identifier(of position: Int) -> String {
            return "state\(position + 1)"
        }

        var lines = ["stateDiagram-v2", "    direction LR", ""]

        for (position, node) in outline.nodes.enumerated() {
            lines.append("    state \"\(node.description.mermaidEscaped)\" as \(identifier(of: position))")
        }
        lines.append("")

        lines.append("    [*] --> \(identifier(of: outline.initialNode))")
        for arrow in outline.arrows {
            let label = arrow.events.map(\.mermaidEscaped).joined(separator: ", ")
            lines.append("    \(identifier(of: arrow.from)) --> \(identifier(of: arrow.to)): \(label)")
        }
        for (position, node) in outline.nodes.enumerated() where node.isEndingState {
            lines.append("    \(identifier(of: position)) --> [*]")
        }

        // The text is black, as it is light where Mermaid is drawn on a dark background.
        if let markedNode = outline.markedNode {
            lines.append("")
            lines.append("    classDef current fill:gold,color:black")
            lines.append("    class \(identifier(of: markedNode)) current")
        }

        return lines.joined(separator: "\n")
    }
}

private extension Character {

    /// If the character can be written as it is in a text in Mermaid. These
    /// are the letters, the digits, the space and a few signs with no meaning
    /// to Mermaid. Characters outside ASCII can be written as they are as well.
    var isPlainInMermaid: Bool {
        guard isASCII else {
            return true
        }
        return isLetter || isNumber || " .,_()'-".contains(self)
    }
}

private extension String {

    /// The string as a text in Mermaid, for the description of a state or the
    /// label of an arrow.
    ///
    /// Mermaid has no way to quote a text, and many characters mean something
    /// to it: a semicolon ends a statement, `%%` starts a comment, and text in
    /// angle brackets is read as HTML. Every ASCII character that is not plain
    /// is written as an entity code, like `#59;` for a semicolon. A line break
    /// is written as `<br/>`. A text with nothing in it is written as a space,
    /// as Mermaid shows the identifier of a state without a description.
    var mermaidEscaped: String {
        var escaped = ""

        for character in self {
            if character.isNewline {
                escaped += "<br/>"
            } else if character.isWhitespace, escaped.suffix(9).lowercased() == "direction" {
                // Mermaid reads a line with the word direction and a direction after
                // it, like LR, as the direction of the diagram, wherever in the line
                // it is, and whether in small letters or capitals.
                escaped += character.entityCodes
            } else if character.isPlainInMermaid {
                escaped.append(character)
            } else {
                escaped += character.entityCodes
            }
        }

        return escaped.allSatisfy(\.isWhitespace) ? "#32;" : escaped
    }
}

private extension Character {

    /// The character as entity codes in Mermaid, one for every Unicode scalar of it.
    var entityCodes: String {
        return unicodeScalars.map { "#\($0.value);" }.joined()
    }
}
