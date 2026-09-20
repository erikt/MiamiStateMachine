import MiamiGraph

/// A graph counting how many times the edges of a vertex are asked for. The
/// count tells how much work an algorithm does, without measuring time. A test
/// of an algorithm doing too much work then fails, where a test measuring time
/// would have to wait for the algorithm to finish.
struct CountingGraph<Element>: Graph {

    /// A reference to the count, as `edges(from:)` is not mutating.
    private final class Counter {
        var count = 0
    }

    private var graph = AdjacencyList<Element>()
    private let counter = Counter()

    init() {}

    /// Number of calls to `edges(from:)`.
    var edgesCallCount: Int {
        counter.count
    }

    var vertices: [Vertex<Element>] {
        graph.vertices
    }

    @discardableResult
    mutating func addVertex(_ data: Element) -> Vertex<Element> {
        graph.addVertex(data)
    }

    mutating func addDirectedEdge(from source: Vertex<Element>,
                                  to destination: Vertex<Element>,
                                  weight: Double)
    {
        graph.addDirectedEdge(from: source, to: destination, weight: weight)
    }

    func edges(from source: Vertex<Element>) -> [Edge<Element>] {
        counter.count += 1
        return graph.edges(from: source)
    }

    func weight(from source: Vertex<Element>, to destination: Vertex<Element>) -> Double? {
        graph.weight(from: source, to: destination)
    }
}
