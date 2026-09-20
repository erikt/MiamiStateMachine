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
        var queue = QueueStack<Vertex<Element>>()
        var isEnqueued = [Bool](repeating: false, count: vertices.count)
        var visited: [Vertex<Element>] = []

        queue.enqueue(source)
        isEnqueued[source.index] = true

        while let vertex = queue.dequeue() {
            visited.append(vertex)
            for edge in edges(from: vertex) where !isEnqueued[edge.destination.index] {
                queue.enqueue(edge.destination)
                isEnqueued[edge.destination.index] = true
            }
        }

        return visited
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
