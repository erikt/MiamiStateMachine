/// A graph of vertices holding values, connected by weighted edges.
///
/// Every edge is directed, and leads from a source to a destination. Two
/// vertices connected in both directions are connected by two edges, one
/// in each direction.
///
/// Conforming types are expected to be value types. A vertex belongs to
/// the graph creating it (and copies of that graph). Using a vertex
/// with an unrelated graph is a programmer error.
package protocol Graph<Element> {

    /// The type of the values held by the vertices.
    associatedtype Element

    /// Creates an empty graph.
    init()

    /// All vertices in the graph, in the order they were added. The
    /// position of a vertex is the same as the `index` of the vertex.
    var vertices: [Vertex<Element>] { get }

    /// Adds a new vertex, holding a value, to the graph.
    /// - Parameter data: The value held by the vertex.
    /// - Returns: The new vertex.
    @discardableResult
    mutating func addVertex(_ data: Element) -> Vertex<Element>

    /// Adds an edge leading from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    ///   - weight: The cost of following the edge.
    /// - Precondition: The weight is a finite number.
    mutating func addEdge(from source: Vertex<Element>,
                          to destination: Vertex<Element>,
                          weight: Double)

    /// All edges starting from a vertex.
    /// - Parameter source: The vertex the edges start from.
    /// - Returns: Edges starting from the vertex.
    func edges(from source: Vertex<Element>) -> [Edge<Element>]

    /// The edge with the lowest weight leading from a vertex
    /// directly to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    /// - Returns: The edge, or `nil` if there is no edge from the
    /// source to the destination.
    func lightestEdge(from source: Vertex<Element>, to destination: Vertex<Element>) -> Edge<Element>?
}

extension Graph {

    /// Adds an unweighted edge (an edge with the weight 1)
    /// leading from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    package mutating func addEdge(from source: Vertex<Element>, to destination: Vertex<Element>) {
        addEdge(from: source, to: destination, weight: 1)
    }

    /// Connects two vertices in both directions, by adding
    /// an edge from each one of them to the other.
    /// - Parameters:
    ///   - first: One of the vertices.
    ///   - second: The other vertex.
    ///   - weight: The cost of following any of the two edges.
    /// - Precondition: The weight is a finite number.
    package mutating func addEdges(between first: Vertex<Element>,
                                   and second: Vertex<Element>,
                                   weight: Double = 1)
    {
        addEdge(from: first, to: second, weight: weight)
        addEdge(from: second, to: first, weight: weight)
    }

    /// The edge with the lowest weight leading from a vertex
    /// directly to another vertex, found among the edges of the source.
    /// - Complexity: O(*k*), where *k* is the number of edges from the source.
    package func lightestEdge(from source: Vertex<Element>, to destination: Vertex<Element>) -> Edge<Element>? {
        precondition(contains(destination), "Vertex is not part of the graph.")
        return edges(from: source)
            .filter { $0.destination.index == destination.index }
            .min { $0.weight < $1.weight }
    }

    /// If the vertex is within the bounds of this graph.
    package func contains(_ vertex: Vertex<Element>) -> Bool {
        vertices.indices.contains(vertex.index)
    }

    /// The edges of the graph, one on every line, in the order of the
    /// vertices they lead from. A vertex without any edges leading from
    /// it has a line of its own.
    ///
    ///     0: A --(1.0)--> 1: B
    ///     0: A --(2.5)--> 2: C
    ///     1: B
    ///     2: C --(1.0)--> 0: A
    package var description: String {
        let lines = vertices.flatMap { vertex in
            let edges = edges(from: vertex)
            return edges.isEmpty ? ["\(vertex)"] : edges.map { "\($0)" }
        }
        return lines.joined(separator: "\n")
    }
}

extension Graph where Element: Equatable {

    /// The first vertex holding a value.
    /// - Parameter data: The value to search for.
    /// - Returns: The vertex, or `nil` if no vertex holds the value.
    /// - Complexity: O(*V*), where *V* is the number of vertices.
    package func firstVertex(holding data: Element) -> Vertex<Element>? {
        vertices.first { $0.data == data }
    }
}
