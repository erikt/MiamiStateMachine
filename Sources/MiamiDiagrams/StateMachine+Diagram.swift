import MiamiStateMachine

/// What a diagram of a state machine shows, whatever language the diagram is
/// written in: the states, and an arrow for every two states connected by
/// transitions.
///
/// Everything is in a decided order, so that a diagram is the same every time
/// it is made. The states are sorted by their descriptions, and are referred
/// to by their positions. This needs the states to have different descriptions.
/// States with the same description are still different states, but the order
/// between them can differ.
struct DiagramOutline {

    /// A state of the state machine.
    struct Node {
        /// The description of the state.
        let description: String

        /// If no transitions lead from the state.
        let isEndingState: Bool
    }

    /// The transitions leading from a state to a state, which can be the same state.
    struct Arrow {
        /// The position of the state the transitions lead from.
        let from: Int

        /// The position of the state the transitions lead to.
        let to: Int

        /// The descriptions of the events of the transitions, sorted.
        let events: [String]
    }

    /// The states, sorted by their descriptions.
    let nodes: [Node]

    /// The position of the initial state.
    let initialNode: Int

    /// The position of a state to mark, which is how a diagram shows
    /// the state the state machine is at. Nothing is marked if nil.
    let markedNode: Int?

    /// The arrows, sorted by the state they lead from, and then by the state they lead to.
    let arrows: [Arrow]
}

// MARK: - Diagram

extension StateMachine {

    // A diagram is about the definition of the state machine. It is made
    // from what the state machine tells everyone about its definition, as
    // this is another module, and that never changes, so it is nonisolated.

    /// What a diagram of the state machine shows.
    /// - Parameter markedState: A state to mark in the diagram, like the
    /// current state. Nothing is marked if it is nil, or if it is not one
    /// of the states of the state machine.
    /// - Complexity: O(*n* log *n*), where *n* is the number of transitions.
    nonisolated func diagramOutline(marking markedState: State?) -> DiagramOutline {
        let sortedStates = states.map { (state: $0, description: "\($0)") }.sorted { $0.description < $1.description }

        var positions: [State: Int] = [:]
        for (position, element) in sortedStates.enumerated() {
            positions[element.state] = position
        }

        func position(of state: State) -> Int {
            guard let position = positions[state] else {
                preconditionFailure("Missing position for \(state). All states of the state machine have a position.")
            }
            return position
        }

        var arrows: [DiagramOutline.Arrow] = []
        for (from, element) in sortedStates.enumerated() {
            for (newState, transitions) in Dictionary(grouping: transitions(from: element.state), by: \.to) {
                let events = transitions.map { "\($0.event)" }.sorted()
                arrows.append(DiagramOutline.Arrow(from: from, to: position(of: newState), events: events))
            }
        }
        arrows.sort { ($0.from, $0.to) < ($1.from, $1.to) }

        return DiagramOutline(
            nodes: sortedStates.map { DiagramOutline.Node(description: $0.description, isEndingState: isEndingState($0.state)) },
            initialNode: position(of: initialState),
            markedNode: markedState.flatMap { positions[$0] },
            arrows: arrows)
    }
}
