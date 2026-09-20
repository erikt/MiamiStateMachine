/// A vertex (node) in a graph, holding a value.
///
/// A vertex is created by adding a value to a graph with
/// `addVertex(_:)`, and belongs to the graph creating it.
package struct Vertex<Element> {

    /// Position of the vertex in the graph it belongs to. Vertices
    /// are numbered from zero, in the order they are added to the graph.
    package let index: Int

    /// The value held by the vertex.
    package let data: Element

    /// Creates a vertex. Only a graph knows the correct index for
    /// a new vertex, so use `addVertex(_:)` of the graph instead of
    /// creating vertices directly.
    /// - Parameters:
    ///   - index: Position of the vertex in its graph.
    ///   - data: The value held by the vertex.
    package init(index: Int, data: Element) {
        self.index = index
        self.data = data
    }
}

extension Vertex: Equatable where Element: Equatable {}
extension Vertex: Hashable where Element: Hashable {}
extension Vertex: Sendable where Element: Sendable {}

extension Vertex: CustomStringConvertible {
    package var description: String {
        return "\(index): \(data)"
    }
}
