import MiamiStateMachine

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
