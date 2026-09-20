/// A graph storing the outgoing edges for every vertex.
///
/// Suitable for sparse graphs (few edges compared to the number
/// of vertices). Several edges from a vertex to the same
/// destination (parallel edges) are allowed.
package struct AdjacencyList<Element>: Graph {

    package private(set) var vertices: [Vertex<Element>] = []

    /// Outgoing edges for each vertex, by vertex index.
    private var adjacencies: [[Edge<Element>]] = []

    package init() {}

    @discardableResult
    package mutating func addVertex(_ data: Element) -> Vertex<Element> {
        let vertex = Vertex(index: vertices.count, data: data)
        vertices.append(vertex)
        adjacencies.append([])
        return vertex
    }

    package mutating func addEdge(from source: Vertex<Element>,
                                  to destination: Vertex<Element>,
                                  weight: Double)
    {
        precondition(contains(source) && contains(destination), "Vertex is not part of the graph.")
        precondition(weight.isFinite, "The weight of an edge has to be a finite number.")
        adjacencies[source.index].append(Edge(source: source, destination: destination, weight: weight))
    }

    /// All edges starting from a vertex, in the order they were added.
    /// - Parameter source: The vertex the edges start from.
    /// - Returns: Edges starting from the vertex.
    /// - Complexity: O(1)
    package func edges(from source: Vertex<Element>) -> [Edge<Element>] {
        precondition(contains(source), "Vertex is not part of the graph.")
        return adjacencies[source.index]
    }
}

extension AdjacencyList: Sendable where Element: Sendable {}

extension AdjacencyList: CustomStringConvertible {
    package var description: String {
        return vertices.map { vertex in
            let destinations = adjacencies[vertex.index].map { "\($0.destination)" }.joined(separator: ", ")
            return "\(vertex) ---> [\(destinations)]"
        }.joined(separator: "\n")
    }
}
