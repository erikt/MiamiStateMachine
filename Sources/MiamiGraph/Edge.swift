/// The kind of connection an edge makes between two vertices.
package enum EdgeType: Sendable {
    /// Connects the source to the destination, but not the other way around.
    case directed

    /// Connects the two vertices in both directions.
    case undirected
}

/// A directed, weighted connection from a vertex to another vertex.
package struct Edge<Element> {

    /// The vertex the edge starts from.
    package let source: Vertex<Element>

    /// The vertex the edge leads to.
    package let destination: Vertex<Element>

    /// The cost of following the edge. Edges in
    /// an unweighted graph all have the weight 1.
    package let weight: Double

    /// Creates an edge from a vertex to another vertex.
    /// - Parameters:
    ///   - source: The vertex the edge starts from.
    ///   - destination: The vertex the edge leads to.
    ///   - weight: The cost of following the edge.
    package init(source: Vertex<Element>, destination: Vertex<Element>, weight: Double = 1) {
        self.source = source
        self.destination = destination
        self.weight = weight
    }
}

extension Edge: Equatable where Element: Equatable {}
extension Edge: Hashable where Element: Hashable {}
extension Edge: Sendable where Element: Sendable {}

extension Edge: CustomStringConvertible {
    package var description: String {
        return "\(source) --(\(weight))--> \(destination)"
    }
}
