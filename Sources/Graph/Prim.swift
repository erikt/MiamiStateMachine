import DataStructures

extension Graph {

    /// Finds a minimum spanning tree, using Prim's algorithm. The tree
    /// connects the vertices with the lowest possible total weight.
    ///
    /// The graph is expected to be undirected. If the graph is not
    /// connected, the tree only spans the vertices connected to
    /// the first vertex.
    /// - Returns: The total weight of the tree, and the tree itself. The
    /// tree has the same vertices as the graph, with undirected edges.
    /// - Complexity: O(*E* log *E*) for an adjacency list, where *E* is
    /// the number of edges.
    package func minimumSpanningTree() -> (cost: Double, tree: AdjacencyList<Element>) {
        var cost = 0.0
        var tree = AdjacencyList<Element>()
        var isVisited = [Bool](repeating: false, count: vertices.count)
        var queue = PriorityQueue<Edge<Element>> {
            $0.weight < $1.weight
        }

        // Vertices are added in order, so they get the
        // same indices in the tree as in the graph.
        for vertex in vertices {
            tree.addVertex(vertex.data)
        }

        func visit(_ vertex: Vertex<Element>) {
            isVisited[vertex.index] = true
            for edge in edges(from: vertex) where !isVisited[edge.destination.index] {
                queue.enqueue(edge)
            }
        }

        guard let start = vertices.first else {
            return (cost: cost, tree: tree)
        }

        visit(start)

        while let smallestEdge = queue.dequeue() {
            let vertex = smallestEdge.destination

            guard !isVisited[vertex.index] else {
                continue
            }

            cost += smallestEdge.weight
            tree.addUndirectedEdge(between: smallestEdge.source, and: vertex, weight: smallestEdge.weight)
            visit(vertex)
        }

        return (cost: cost, tree: tree)
    }
}
