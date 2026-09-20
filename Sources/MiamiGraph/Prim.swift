import MiamiDataStructures

extension Graph {

    /// Finds a minimum spanning tree, using Prim's algorithm. The tree
    /// connects the vertices with the lowest possible total weight.
    ///
    /// Every edge of the graph is expected to have an edge leading the
    /// other way, with the same weight. If the graph is not connected,
    /// the tree only spans the vertices connected to the first vertex.
    /// - Returns: The total weight of the tree, and the tree itself. The
    /// tree has the same vertices as the graph, connected in both directions.
    /// - Complexity: O(*E* log *E*) for an adjacency list, where *E* is
    /// the number of edges.
    package func minimumSpanningTree() -> (cost: Double, tree: AdjacencyList<Element>) {
        var tree = AdjacencyList<Element>()

        // Vertices are added in order, so they get the
        // same indices in the tree as in the graph.
        for vertex in vertices {
            tree.addVertex(vertex.data)
        }

        guard let start = vertices.first else {
            return (cost: 0, tree: tree)
        }

        var totalWeight = 0.0
        var isInTree = [Bool](repeating: false, count: vertices.count)

        // Edges leading out of the tree, the lightest first.
        var candidates = PriorityQueue<Prioritized<Edge<Element>, Double>>()

        func addToTree(_ vertex: Vertex<Element>) {
            isInTree[vertex.index] = true
            for edge in edges(from: vertex) where !isInTree[edge.destination.index] {
                candidates.enqueue(Prioritized(edge, priority: edge.weight))
            }
        }

        addToTree(start)

        while let lightest = candidates.dequeue()?.value {
            if isInTree[lightest.destination.index] {
                // A lighter edge has connected the destination
                // to the tree since this edge was queued.
                continue
            }

            tree.addEdges(between: lightest.source, and: lightest.destination, weight: lightest.weight)
            totalWeight += lightest.weight
            addToTree(lightest.destination)
        }

        return (cost: totalWeight, tree: tree)
    }
}
