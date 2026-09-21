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
        lines.append("    \(Self.initialPointName.dotQuoted) [shape=point]")
        for (position, node) in outline.nodes.enumerated() {
            var attributes: [String] = []
            if names[position] != node.description {
                attributes.append("label=\(node.description.dotQuoted)")
            }
            if node.isEndingState {
                attributes.append("shape=doublecircle")
            }
            if position == outline.markedNode {
                attributes.append("style=filled")
                attributes.append("fillcolor=gold")
            }
            if !attributes.isEmpty {
                lines.append("    \(names[position].dotQuoted) [\(attributes.joined(separator: ", "))]")
            }
        }
        lines.append("")

        lines.append("    \(Self.initialPointName.dotQuoted) -> \(names[outline.initialNode].dotQuoted)")
        for arrow in outline.arrows {
            let label = arrow.events.joined(separator: ", ")
            lines.append("    \(names[arrow.from].dotQuoted) -> \(names[arrow.to].dotQuoted) [label=\(label.dotQuoted)]")
        }
        lines.append("}")

        return lines.joined(separator: "\n")
    }

    /// The name of the point with the arrow leading to the initial state. It
    /// is how the start of a state machine is written in PlantUML and Mermaid.
    private static var initialPointName: String {
        return "[*]"
    }

    /// A name for every node, which is the description of its state. No two
    /// nodes have the same name. If a name is already taken, by a state with
    /// the same description or by the reserved name, a number is added to it.
    /// - Parameters:
    ///   - nodes: The nodes to name, sorted by their descriptions.
    ///   - reserved: A name no node is to get.
    /// - Returns: The names of the nodes, by their positions.
    private static func dotNames(of nodes: [DiagramOutline.Node], reserving reserved: String) -> [String] {
        var taken: Set<String> = [reserved]

        // In the order of the descriptions, so that the names depend on
        // nothing else, like the order the states happen to come in.
        return nodes.map { node in
            var name = node.description
            var number = 1
            while !taken.insert(name).inserted {
                number += 1
                name = "\(node.description) (\(number))"
            }
            return name
        }
    }
}

private extension String {

    /// The string as a quoted string in the DOT language. Quotes and
    /// backslashes are escaped, and a line break is written as `\n`.
    var dotQuoted: String {
        var quoted = "\""
        for character in self {
            switch character {
            case "\"":
                quoted += "\\\""
            case "\\":
                quoted += "\\\\"
            case _ where character.isNewline:
                quoted += "\\n"
            default:
                quoted.append(character)
            }
        }
        return quoted + "\""
    }
}
