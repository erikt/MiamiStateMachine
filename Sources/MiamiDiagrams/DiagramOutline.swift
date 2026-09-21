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
