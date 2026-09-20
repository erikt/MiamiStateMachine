import MiamiGraph

/// The definition of a state machine as a graph. Every state in the
/// transitions is a vertex, and two states directly connected by at
/// least one transition are connected by an edge.
///
/// The graph is used to answer questions about the state machine
/// definition as a whole, like how to get from a state to another state.
struct TransitionGraph<Event: Hashable & Sendable, State: Hashable & Sendable>: Sendable {

    /// A direct connection from a state to another state.
    private struct Hop: Hashable, Sendable {
        let from: State
        let to: State
    }

    // MARK: - Private properties

    /// The states, connected by edges in the direction of the transitions.
    private var states = AdjacencyList<State>()

    /// The vertex of each state.
    private var verticesByState: [State: Vertex<State>] = [:]

    /// The transition taking the state machine from a state directly to
    /// another state. If several events connect the same two states, one of
    /// the transitions is used for them all, as they are equally good when
    /// looking for a path.
    private var transitionsByHop: [Hop: StateTransition<Event, State>] = [:]

    // MARK: - Initialization

    /// Creates a graph of the states in the transitions.
    /// - Parameter transitions: Transitions defining a state machine.
    init(transitions: Set<StateTransition<Event, State>>) {
        for transition in transitions {
            let hop = Hop(from: transition.from, to: transition.to)

            guard transitionsByHop[hop] == nil else {
                // Another event already connects the two states.
                continue
            }

            let source = vertex(for: transition.from)
            let destination = vertex(for: transition.to)
            states.addDirectedEdge(from: source, to: destination)
            transitionsByHop[hop] = transition
        }
    }

    // MARK: - Methods

    /// The shortest path from a state to another state. This is the way
    /// between the states needing the fewest transitions.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// - Parameters:
    ///   - state: State to start from.
    ///   - newState: State to go to.
    /// - Returns: The transitions to make, in order, to get from the state to
    /// the new state. If the new state cannot be reached from the state,
    /// it returns nil. The path is empty if the two states are the same.
    func shortestPath(from state: State, to newState: State) -> [StateTransition<Event, State>]? {
        guard state != newState else {
            // Already there. This is also true for
            // states without any transitions at all.
            return []
        }

        guard let source = verticesByState[state],
              let destination = verticesByState[newState],
              let path = states.shortestPath(from: source, to: destination)
        else {
            return nil
        }

        return path.map { edge in
            let hop = Hop(from: edge.source.data, to: edge.destination.data)
            guard let transition = transitionsByHop[hop] else {
                preconditionFailure("Missing transition from \(hop.from) to \(hop.to). All edges are created from a transition.")
            }
            return transition
        }
    }

    // MARK: - Private methods

    /// The vertex of a state. If the state is not yet
    /// part of the graph, a vertex is added for it.
    /// - Parameter state: State to get the vertex of.
    /// - Returns: The vertex of the state.
    private mutating func vertex(for state: State) -> Vertex<State> {
        if let vertex = verticesByState[state] {
            return vertex
        }

        let vertex = states.addVertex(state)
        verticesByState[state] = vertex
        return vertex
    }
}
