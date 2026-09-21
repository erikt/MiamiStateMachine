import MiamiStateMachine

// MARK: - Diagram for Graphviz

extension StateMachine {

    /// The definition of the state machine as a diagram, in the DOT language
    /// of Graphviz. Save it to a file, and Graphviz draws the diagram:
    ///
    ///     dot -Tsvg order.dot -o order.svg
    ///
    /// Every state is a node, named by its description. The states connected
    /// by transitions are connected by an arrow, labeled with the events. If
    /// several events lead from a state to the same state, they share one
    /// arrow. The initial state has an arrow leading to it from a point, and
    /// the ending states are drawn with a double outline.
    ///
    /// The diagram is the same every time, whatever order the transitions were
    /// given in, so it can be compared with a saved diagram. This needs the
    /// states to have different descriptions. States with the same description
    /// are still different nodes, told apart by a number added to their names,
    /// but which of the states that gets which number can differ.
    /// - Complexity: O(*n* log *n*), where *n* is the number of transitions.
    public nonisolated var dotDiagram: String {
        return dotDiagram(marking: nil)
    }

    /// The state machine as a diagram in the DOT language of Graphviz, like
    /// `dotDiagram`, with the current state marked by being filled with color.
    ///
    /// The diagram is of one moment. The state machine may have moved on
    /// when the diagram is drawn.
    /// - Complexity: O(*n* log *n*), where *n* is the number of transitions.
    public var dotDiagramWithCurrentState: String {
        return dotDiagram(marking: state)
    }

    /// The definition of the state machine as a diagram in the DOT language,
    /// with a state marked.
    /// - Parameter markedState: The state to mark. Nothing is marked if nil.
    /// - Returns: The diagram.
    private nonisolated func dotDiagram(marking markedState: State?) -> String {
        let outline = diagramOutline(marking: markedState)
        let names = Self.dotNames(of: outline.nodes, reserving: Self.initialPointName)

        var lines = ["digraph {", "    rankdir=LR", "    node [shape=circle]", ""]

        // The nodes not drawn like the rest.
        lines.append("    \(quoted(Self.initialPointName)) [shape=point]")
        for (position, node) in outline.nodes.enumerated() {
            var attributes: [String] = []
            if names[position] != node.description.dotEscaped {
                attributes.append("label=\(quoted(node.description.dotEscaped))")
            }
            if node.isEndingState {
                attributes.append("shape=doublecircle")
            }
            if position == outline.markedNode {
                attributes.append("style=filled")
                attributes.append("fillcolor=gold")
            }
            if !attributes.isEmpty {
                lines.append("    \(quoted(names[position])) [\(attributes.joined(separator: ", "))]")
            }
        }
        lines.append("")

        lines.append("    \(quoted(Self.initialPointName)) -> \(quoted(names[outline.initialNode]))")
        for arrow in outline.arrows {
            let label = arrow.events.map(\.dotEscaped).joined(separator: ", ")
            lines.append("    \(quoted(names[arrow.from])) -> \(quoted(names[arrow.to])) [label=\(quoted(label))]")
        }
        lines.append("}")

        return lines.joined(separator: "\n")

        // The names and labels are escaped already.
        func quoted(_ escaped: String) -> String {
            return "\"\(escaped)\""
        }
    }

    /// The name of the point with the arrow leading to the initial state. It
    /// is how the start of a state machine is written in PlantUML and Mermaid.
    private static var initialPointName: String {
        return "[*]"
    }

    /// A name for every node, which is the description of its state, escaped
    /// to be written in quotes. No two nodes have the same name. If a name is
    /// already taken, a number is added to it. It can be taken by a state
    /// with the same description, by a state with a description that is
    /// written the same way, like one with another kind of line break, or by
    /// the reserved name.
    /// - Parameters:
    ///   - nodes: The nodes to name, sorted by their descriptions.
    ///   - reserved: A name no node is to get.
    /// - Returns: The names of the nodes, by their positions.
    private static func dotNames(of nodes: [DiagramOutline.Node], reserving reserved: String) -> [String] {
        var taken: Set<String> = [reserved]

        // The number last added to a name. Counting goes on from it, and does not
        // start over for every state, when many states have the same description.
        var lastNumbers: [String: Int] = [:]

        // In the order of the descriptions, so that the names depend on
        // nothing else, like the order the states happen to come in.
        return nodes.map { node in
            let wanted = node.description.dotEscaped
            var name = wanted
            var number = lastNumbers[wanted, default: 1]
            while !taken.insert(name).inserted {
                number += 1
                name = "\(wanted) (\(number))"
            }
            lastNumbers[wanted] = number
            return name
        }
    }
}

private extension String {

    /// The string as the text of a quoted string in the DOT language,
    /// without the quotes around it.
    ///
    /// A quote and a backslash are escaped, and a line break is written as
    /// `\n`. An ampersand is written as an entity, as Graphviz reads entities
    /// in the text it draws. A control character is written as a space, as
    /// Graphviz does not read a file with a null character, and passes the
    /// others on to files that cannot be read.
    ///
    /// The text is gone through by Unicode scalar, and not by character. A
    /// quote followed by a combining mark is one character, which is not a
    /// quote, and would be written as it is.
    var dotEscaped: String {
        var escaped = ""

        for character in self {
            guard !character.isNewline else {
                // A carriage return and a line feed are one character, and one line break.
                escaped += "\\n"
                continue
            }

            for scalar in character.unicodeScalars {
                switch scalar {
                case "\"":
                    escaped += "\\\""
                case "\\":
                    escaped += "\\\\"
                case "&":
                    escaped += "&amp;"
                case _ where scalar.properties.generalCategory == .control:
                    escaped += " "
                default:
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }

        return escaped
    }
}
