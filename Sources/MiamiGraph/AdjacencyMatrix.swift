/// A graph storing the edge weights in a matrix, with a
/// row for each source and a column for each destination.
///
/// Suitable for dense graphs (many edges compared to the number
/// of vertices), where looking up the weight between two vertices
/// needs to be fast. There can only be one edge from a vertex
/// to another vertex. Adding another replaces the first.
package struct AdjacencyMatrix<Element>: Graph {

    package private(set) var vertices: [Vertex<Element>] = []

    /// Weight of the edge from a vertex (row) to another
    /// vertex (column), by vertex index. `nil` means there is no edge.
    private var weights: [[Double?]] = []

    package init() {}

    /// Adds a new vertex, holding a value, to the graph.
    /// - Parameter data: The value held by the vertex.
    /// - Returns: The new vertex.
    /// - Complexity: O(*V*), where *V* is the number of vertices.
    @discardableResult
    package mutating func addVertex(_ data: Element) -> Vertex<Element> {
        let vertex = Vertex(index: vertices.count, data: data)
        vertices.append(vertex)
        for row in weights.indices {
            weights[row].append(nil)
        }
        weights.append([Double?](repeating: nil, count: vertices.count))
        return vertex
    }

    package mutating func addDirectedEdge(from source: Vertex<Element>,
                                          to destination: Vertex<Element>,
                                          weight: Double)
    {
        precondition(contains(source) && contains(destination), "Vertex is not part of the graph.")
        weights[source.index][destination.index] = weight
    }

    /// All edges starting from a vertex, ordered by the index of the destination.
    /// - Parameter source: The vertex the edges start from.
    /// - Returns: Edges starting from the vertex.
    /// - Complexity: O(*V*), where *V* is the number of vertices.
    package func edges(from source: Vertex<Element>) -> [Edge<Element>] {
        precondition(contains(source), "Vertex is not part of the graph.")
        return zip(vertices, weights[source.index]).compactMap { destination, weight in
            weight.map { Edge(source: source, destination: destination, weight: $0) }
        }
    }

    /// The weight of the edge leading from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    /// - Returns: The weight of the edge, or `nil` if there is no edge
    /// from the source to the destination.
    /// - Complexity: O(1)
    package func weight(from source: Vertex<Element>, to destination: Vertex<Element>) -> Double? {
        precondition(contains(source) && contains(destination), "Vertex is not part of the graph.")
        return weights[source.index][destination.index]
    }
}

extension AdjacencyMatrix: Sendable where Element: Sendable {}

extension AdjacencyMatrix: CustomStringConvertible {
    package var description: String {
        let verticesDescription = vertices.map { "\($0)" }.joined(separator: "\n")
        let weightsDescription = weights.map { row in
            row.map { weight in
                weight.map { "\($0)" } ?? "ø"
            }.joined(separator: "\t")
        }.joined(separator: "\n")
        return "\(verticesDescription)\n\n\(weightsDescription)"
    }
}
