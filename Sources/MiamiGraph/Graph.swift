/// A graph of vertices holding values, connected by weighted edges.
///
/// Edges are stored as directed edges. An undirected edge is
/// two directed edges, one in each direction.
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
    mutating func addDirectedEdge(from source: Vertex<Element>,
                                  to destination: Vertex<Element>,
                                  weight: Double)

    /// All edges starting from a vertex.
    /// - Parameter source: The vertex the edges start from.
    /// - Returns: Edges starting from the vertex.
    func edges(from source: Vertex<Element>) -> [Edge<Element>]

    /// The weight of the edge leading from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    /// - Returns: The weight of the edge, or `nil` if there is no edge
    /// from the source to the destination. If there are several such
    /// edges, the lowest weight is returned.
    func weight(from source: Vertex<Element>, to destination: Vertex<Element>) -> Double?
}

extension Graph {

    /// Adds an unweighted edge (an edge with the weight 1)
    /// leading from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    package mutating func addDirectedEdge(from source: Vertex<Element>,
                                          to destination: Vertex<Element>)
    {
        addDirectedEdge(from: source, to: destination, weight: 1)
    }

    /// Adds edges in both directions between two vertices.
    /// - Parameters:
    ///   - source: The first vertex.
    ///   - destination: The second vertex.
    ///   - weight: The cost of following the edge, in any direction.
    package mutating func addUndirectedEdge(between source: Vertex<Element>,
                                            and destination: Vertex<Element>,
                                            weight: Double = 1)
    {
        addDirectedEdge(from: source, to: destination, weight: weight)
        addDirectedEdge(from: destination, to: source, weight: weight)
    }

    /// Adds an edge of a specific type between two vertices.
    /// - Parameters:
    ///   - edgeType: If the edge is directed or undirected.
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    ///   - weight: The cost of following the edge.
    package mutating func add(_ edgeType: EdgeType,
                              from source: Vertex<Element>,
                              to destination: Vertex<Element>,
                              weight: Double = 1)
    {
        switch edgeType {
        case .directed:
            addDirectedEdge(from: source, to: destination, weight: weight)
        case .undirected:
            addUndirectedEdge(between: source, and: destination, weight: weight)
        }
    }

    /// If the vertex is within the bounds of this graph.
    package func contains(_ vertex: Vertex<Element>) -> Bool {
        vertices.indices.contains(vertex.index)
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
