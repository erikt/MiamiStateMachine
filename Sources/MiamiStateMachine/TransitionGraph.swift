import MiamiGraph

/// The definition of a state machine as a graph. Every state in the
/// transitions is a vertex, and two states directly connected by at
/// least one transition are connected by an edge.
///
/// The graph is used to answer questions about the state machine
/// definition as a whole, like how to get from a state to another state,
/// or which states cannot be reached at all.
///
/// A state not part of any transition is not part of the graph. Nothing
/// leads to or from such a state, and it can only be reached from itself.
struct TransitionGraph<Event: Hashable & Sendable, State: Hashable & Sendable>: Sendable {

    /// A direct connection from a state to another state.
    private struct Hop: Hashable, Sendable {
        let from: State
        let to: State
    }

    // MARK: - Private properties

    /// The states, connected by edges in the direction of the transitions.
    private var graph = AdjacencyList<State>()

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
            graph.addEdge(from: source, to: destination)
            transitionsByHop[hop] = transition
        }
    }

    // MARK: - Properties

    /// All states a transition leads from or to.
    var states: Set<State> {
        return Set(verticesByState.keys)
    }

    /// If there is a way from a state back to the same state, by one
    /// transition or several.
    var hasCycle: Bool {
        return graph.hasCycle
    }

    // MARK: - Methods

    /// The shortest path from a state to another state. This is the way
    /// between the states needing the fewest transitions.
    ///
    /// Every transition is one step, so the path is found with a breadth-first
    /// search of the states, stopping when the new state is reached.
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
              let path = graph.pathWithFewestEdges(from: source, to: destination)
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

    /// All states that can be reached from a state, by no transition,
    /// one transition or several. The state itself is always one of them.
    /// - Parameter state: State to start from.
    /// - Returns: The state, and every state there is a path to from it.
    func reachableStates(from state: State) -> Set<State> {
        guard let vertex = verticesByState[state] else {
            return [state]
        }
        return Set(graph.breadthFirstTraversal(from: vertex).map(\.data))
    }

    /// All states with a path to at least one of some states. Every one
    /// of those states is included, having an empty path to itself.
    ///
    /// The states are found by one single search of the transitions
    /// backwards, starting from all the states at once.
    /// - Parameter destinations: The states to find the paths to.
    /// - Returns: The destinations, and every state with a path to any of them.
    func states(leadingToAnyOf destinations: Set<State>) -> Set<State> {
        let vertices = destinations.compactMap { verticesByState[$0] }
        let leading = graph.reversed().breadthFirstTraversal(from: vertices).map(\.data)
        return destinations.union(leading)
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

        let vertex = graph.addVertex(state)
        verticesByState[state] = vertex
        return vertex
    }
}
