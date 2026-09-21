// MARK: - Diagram

extension StateMachine {

    // A diagram is about the definition of the state machine. Like the other
    // nonisolated members, it only uses constant properties.

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
        let names = nodeNames(reserving: Self.initialPointName)

        func name(of state: State) -> String {
            guard let name = names[state] else {
                preconditionFailure("Missing name for \(state). All states of the state machine have a name.")
            }
            return name
        }

        // The nodes not drawn like the rest.
        var nodes: [(name: String, attributes: [String])] = []
        for (state, name) in names {
            var attributes: [String] = []
            if name != "\(state)" {
                attributes.append("label=\("\(state)".dotQuoted)")
            }
            if isEndingState(state) {
                attributes.append("shape=doublecircle")
            }
            if !attributes.isEmpty {
                nodes.append((name, attributes))
            }
        }

        // One arrow for every two states connected by at least one transition.
        var arrows: [(from: String, to: String, events: [String])] = []
        for (state, from) in names {
            for (newState, transitions) in Dictionary(grouping: transitions(from: state), by: \.to) {
                arrows.append((from, name(of: newState), transitions.map { "\($0.event)" }.sorted()))
            }
        }

        var lines = ["digraph {", "    rankdir=LR", "    node [shape=circle]", ""]

        lines.append("    \(Self.initialPointName.dotQuoted) [shape=point]")
        for node in nodes.sorted(by: { $0.name < $1.name }) {
            lines.append("    \(node.name.dotQuoted) [\(node.attributes.joined(separator: ", "))]")
        }
        lines.append("")

        lines.append("    \(Self.initialPointName.dotQuoted) -> \(name(of: initialState).dotQuoted)")
        for arrow in arrows.sorted(by: { ($0.from, $0.to) < ($1.from, $1.to) }) {
            let label = arrow.events.joined(separator: ", ")
            lines.append("    \(arrow.from.dotQuoted) -> \(arrow.to.dotQuoted) [label=\(label.dotQuoted)]")
        }
        lines.append("}")

        return lines.joined(separator: "\n")
    }

    /// The name of the point with the arrow leading to the initial state. It
    /// is how the start of a state machine is written in PlantUML and Mermaid.
    private static var initialPointName: String {
        return "[*]"
    }

    /// A name for the node of every state, which is the description of the
    /// state. No two nodes have the same name. If a name is already taken,
    /// by a state with the same description or by the reserved name, a number
    /// is added to it.
    /// - Parameter reserved: A name no state is to get.
    /// - Returns: The names of the nodes, by their states.
    private nonisolated func nodeNames(reserving reserved: String) -> [State: String] {
        var names: [State: String] = [:]
        var taken: Set<String> = [reserved]

        // In the order of the descriptions, so that the names depend on
        // nothing else, like the order the states happen to come in.
        for (state, description) in states.map({ ($0, "\($0)") }).sorted(by: { $0.1 < $1.1 }) {
            var name = description
            var number = 1
            while !taken.insert(name).inserted {
                number += 1
                name = "\(description) (\(number))"
            }
            names[state] = name
        }

        return names
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
