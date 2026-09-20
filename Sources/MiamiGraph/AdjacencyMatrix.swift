/// A graph storing the edge weights in a matrix, with a
/// row for each source and a column for each destination.
///
/// Suitable for dense graphs (many edges compared to the number
/// of vertices), where looking up the edge between two vertices
/// needs to be fast. There can only be one edge from a vertex
/// to another vertex. Adding another replaces the first.
package struct AdjacencyMatrix<Element>: Graph {

    package private(set) var vertices: [Vertex<Element>] = []

    /// The weight of the edge from a vertex (row) to another vertex
    /// (column), by vertex index. Where there is no edge, the weight is
    /// infinite. That is the one weight an edge cannot have, and a plain
    /// number takes half the memory of a number that can be missing.
    private var weights: [[Double]] = []

    package init() {}

    /// Adds a new vertex, holding a value, to the graph.
    /// - Parameter data: The value held by the vertex.
    /// - Returns: The new vertex.
    /// - Complexity: O(*V*), where *V* is the number of vertices.
    @discardableResult
    package mutating func addVertex(_ data: Element) -> Vertex<Element> {
        let vertex = Vertex(index: vertices.count, data: data)
        vertices.append(vertex)

        // A column for the vertex in every row, and then a row of its own.
        for row in weights.indices {
            weights[row].append(.infinity)
        }
        weights.append([Double](repeating: .infinity, count: vertices.count))

        return vertex
    }

    package mutating func addEdge(from source: Vertex<Element>,
                                  to destination: Vertex<Element>,
                                  weight: Double)
    {
        precondition(contains(source) && contains(destination), "Vertex is not part of the graph.")
        precondition(weight.isFinite, "The weight of an edge has to be a finite number.")
        weights[source.index][destination.index] = weight
    }

    /// All edges starting from a vertex, ordered by the index of the destination.
    /// - Parameter source: The vertex the edges start from.
    /// - Returns: Edges starting from the vertex.
    /// - Complexity: O(*V*), where *V* is the number of vertices.
    package func edges(from source: Vertex<Element>) -> [Edge<Element>] {
        precondition(contains(source), "Vertex is not part of the graph.")
        return vertices.compactMap { destination in
            edge(from: source, to: destination)
        }
    }

    /// The edge leading from a vertex directly to another vertex. There is
    /// only one such edge in a matrix, so it is also the lightest one.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    /// - Returns: The edge, or `nil` if there is no edge from the
    /// source to the destination.
    /// - Complexity: O(1)
    package func lightestEdge(from source: Vertex<Element>, to destination: Vertex<Element>) -> Edge<Element>? {
        precondition(contains(source) && contains(destination), "Vertex is not part of the graph.")
        return edge(from: source, to: destination)
    }

    /// The edge of a cell in the matrix, if the cell has an edge.
    private func edge(from source: Vertex<Element>, to destination: Vertex<Element>) -> Edge<Element>? {
        let weight = weights[source.index][destination.index]
        return weight.isFinite ? Edge(source: source, destination: destination, weight: weight) : nil
    }
}

extension AdjacencyMatrix: Sendable where Element: Sendable {}

// The description is the one shared by all graphs.
extension AdjacencyMatrix: CustomStringConvertible {}
