import MiamiDataStructures

// MARK: - Traversal

extension Graph {

    /// All vertices reachable from a vertex, in breadth-first order.
    ///
    /// The vertices closest to the source (counted in number of edges)
    /// come first. Neighbors are visited in the order of `edges(from:)`.
    /// - Parameter source: The vertex to start from.
    /// - Returns: The reachable vertices, starting with the source.
    package func breadthFirstTraversal(from source: Vertex<Element>) -> [Vertex<Element>] {
        return breadthFirstTraversal(from: [source])
    }

    /// All vertices reachable from at least one of several vertices, in
    /// breadth-first order.
    ///
    /// The sources come first, in the order given, followed by the vertices
    /// one edge from a source, then two edges, and so on. A vertex is only
    /// included once, also when it can be reached from several sources.
    /// - Parameter sources: The vertices to start from.
    /// - Returns: The reachable vertices, starting with the sources.
    /// - Complexity: O(*V* + *E*) for an adjacency list, where *V* is the
    /// number of vertices and *E* the number of edges. It does not
    /// depend on the number of sources.
    package func breadthFirstTraversal(from sources: [Vertex<Element>]) -> [Vertex<Element>] {
        var queue = Queue<Vertex<Element>>()
        var isEnqueued = [Bool](repeating: false, count: vertices.count)
        var visited: [Vertex<Element>] = []

        for source in sources {
            precondition(contains(source), "Vertex is not part of the graph.")
            if !isEnqueued[source.index] {
                queue.enqueue(source)
                isEnqueued[source.index] = true
            }
        }

        while let vertex = queue.dequeue() {
            visited.append(vertex)
            for edge in edges(from: vertex) where !isEnqueued[edge.destination.index] {
                queue.enqueue(edge.destination)
                isEnqueued[edge.destination.index] = true
            }
        }

        return visited
    }

    /// The path with the fewest edges from a vertex to another vertex,
    /// found with a breadth-first search. The weights of the edges are
    /// not considered. Use `shortestPath(from:to:)` for the path with
    /// the lowest total weight.
    ///
    /// The search stops when the destination is reached, so it only
    /// visits the vertices at least as close to the source.
    ///
    /// If there is more than one path with the fewest edges, one of them
    /// is returned.
    /// - Parameters:
    ///   - source: The vertex the path starts from.
    ///   - destination: The vertex the path leads to.
    /// - Returns: The edges to follow from the source, or `nil` if the destination
    /// cannot be reached from the source. The path to the source itself is empty.
    /// - Complexity: O(*V* + *E*) for an adjacency list, where *V* is the
    /// number of vertices and *E* the number of edges.
    package func pathWithFewestEdges(from source: Vertex<Element>,
                                     to destination: Vertex<Element>) -> [Edge<Element>]?
    {
        precondition(contains(source), "Vertex is not part of the graph.")

        guard contains(destination) else {
            return nil
        }

        guard source.index != destination.index else {
            // Already there.
            return []
        }

        // The edge every vertex was reached by. A vertex is reached
        // for the first time by a path with the fewest edges to it.
        var incomingEdges = [Edge<Element>?](repeating: nil, count: vertices.count)
        var isReached = [Bool](repeating: false, count: vertices.count)
        var queue = Queue<Vertex<Element>>()

        isReached[source.index] = true
        queue.enqueue(source)

        search: while let vertex = queue.dequeue() {
            for edge in edges(from: vertex) where !isReached[edge.destination.index] {
                isReached[edge.destination.index] = true
                incomingEdges[edge.destination.index] = edge

                if edge.destination.index == destination.index {
                    break search
                }
                queue.enqueue(edge.destination)
            }
        }

        guard isReached[destination.index] else {
            return nil
        }

        // Follow the edges back from the destination. The
        // source is the only vertex reached without an edge.
        var path: [Edge<Element>] = []
        var index = destination.index
        while let edge = incomingEdges[index] {
            path.append(edge)
            index = edge.source.index
        }
        return path.reversed()
    }

    /// All vertices reachable from a vertex, in depth-first (pre-order) order.
    ///
    /// Each path is followed as far as possible before backtracking.
    /// Neighbors are visited in the order of `edges(from:)`.
    /// - Parameter source: The vertex to start from.
    /// - Returns: The reachable vertices, starting with the source.
    package func depthFirstTraversal(from source: Vertex<Element>) -> [Vertex<Element>] {
        // The edges of a vertex on the stack, and how
        // many of the edges have been followed.
        typealias Frame = (edges: [Edge<Element>], followedCount: Int)

        var stack = Stack<Frame>()
        var isVisited = [Bool](repeating: false, count: vertices.count)
        var visited: [Vertex<Element>] = []

        func visit(_ vertex: Vertex<Element>) {
            isVisited[vertex.index] = true
            visited.append(vertex)
            stack.push((edges: edges(from: vertex), followedCount: 0))
        }

        visit(source)

        while var frame = stack.pop() {
            while frame.followedCount < frame.edges.count {
                let destination = frame.edges[frame.followedCount].destination
                frame.followedCount += 1

                if !isVisited[destination.index] {
                    // Come back to the rest of the edges later.
                    stack.push(frame)
                    visit(destination)
                    break
                }
            }
        }

        return visited
    }
}

// MARK: - Cycle detection

/// Progress for a vertex during the search for cycles.
private enum CycleSearchState {
    /// Not reached yet.
    case unvisited
    /// On the path currently being followed.
    case onPath
    /// Completely searched, without finding any cycle.
    case done
}

extension Graph {

    /// If a cycle can be reached from a vertex, following the
    /// direction of the edges.
    ///
    /// An edge from a vertex to itself is a cycle. So are two vertices
    /// connected in both directions, as that is an edge each way.
    /// - Parameter source: The vertex to start from.
    /// - Returns: If there is a cycle reachable from the vertex.
    /// - Complexity: O(*V* + *E*), where *V* is the number of vertices
    /// and *E* the number of edges.
    package func hasCycle(reachableFrom source: Vertex<Element>) -> Bool {
        var states = [CycleSearchState](repeating: .unvisited, count: vertices.count)
        return hasCycle(reachableFrom: source, states: &states)
    }

    /// If there is a cycle anywhere in the graph, following the
    /// direction of the edges.
    ///
    /// An edge from a vertex to itself is a cycle. So are two vertices
    /// connected in both directions, as that is an edge each way.
    /// - Complexity: O(*V* + *E*), where *V* is the number of vertices
    /// and *E* the number of edges.
    package var hasCycle: Bool {
        var states = [CycleSearchState](repeating: .unvisited, count: vertices.count)
        return vertices.contains { vertex in
            states[vertex.index] == .unvisited && hasCycle(reachableFrom: vertex, states: &states)
        }
    }

    private func hasCycle(reachableFrom source: Vertex<Element>,
                          states: inout [CycleSearchState]) -> Bool
    {
        // A vertex on the path being followed, its edges, and how many of
        // the edges have been followed. The path is kept on a stack and not
        // in recursive calls, so the depth of the graph is not limited by
        // the size of the call stack.
        typealias Step = (vertex: Vertex<Element>, edges: [Edge<Element>], followedCount: Int)

        var path = Stack<Step>()

        func follow(_ vertex: Vertex<Element>) {
            states[vertex.index] = .onPath
            path.push((vertex: vertex, edges: edges(from: vertex), followedCount: 0))
        }

        follow(source)

        while var step = path.pop() {
            guard step.followedCount < step.edges.count else {
                // Every edge is followed, without finding any cycle.
                states[step.vertex.index] = .done
                continue
            }

            let destination = step.edges[step.followedCount].destination
            step.followedCount += 1

            // Come back to the rest of the edges later.
            path.push(step)

            switch states[destination.index] {
            case .onPath:
                // Back at a vertex on the current path.
                return true
            case .unvisited:
                follow(destination)
            case .done:
                break
            }
        }

        return false
    }
}
