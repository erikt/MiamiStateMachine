import Testing
import MiamiGraph

/// The graph implementations. Used as argument for tests of behavior
/// all graphs should share, no matter how they are implemented.
enum GraphKind: CaseIterable, Codable {
    case adjacencyList, adjacencyMatrix

    func makeGraph() -> any Graph<String> {
        switch self {
        case .adjacencyList: AdjacencyList<String>()
        case .adjacencyMatrix: AdjacencyMatrix<String>()
        }
    }
}

/// A graph with named vertices, together with a way
/// to get hold of the vertices by their names.
struct Fixture {
    typealias EdgeDefinition = (from: String, to: String, weight: Double)

    var graph: any Graph<String>
    private var verticesByName: [String: Vertex<String>] = [:]

    init(_ kind: GraphKind,
         vertices: [String],
         _ edgeType: EdgeType = .directed,
         edges: [EdgeDefinition] = [],
         sourceLocation: SourceLocation = #_sourceLocation) throws
    {
        graph = kind.makeGraph()
        for name in vertices {
            verticesByName[name] = graph.addVertex(name)
        }
        for edge in edges {
            graph.add(edgeType,
                      from: try vertex(edge.from, sourceLocation: sourceLocation),
                      to: try vertex(edge.to, sourceLocation: sourceLocation),
                      weight: edge.weight)
        }
    }

    func vertex(_ name: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Vertex<String> {
        try #require(verticesByName[name], "No vertex named \(name) in fixture.", sourceLocation: sourceLocation)
    }
}

extension Fixture {

    /// A directed, unweighted graph without cycles, but with
    /// two paths from A to D. X cannot be reached.
    ///
    ///       A
    ///      ↙ ↘
    ///     B   C      X
    ///      ↘ ↙
    ///       D → E
    static func diamond(_ kind: GraphKind) throws -> Fixture {
        try Fixture(kind, vertices: ["A", "B", "C", "D", "E", "X"], edges: [
            ("A", "B", 1), ("A", "C", 1), ("B", "D", 1), ("C", "D", 1), ("D", "E", 1),
        ])
    }

    /// A weighted graph where the edge with the lowest weight, or the
    /// path with the fewest edges, is often not the best choice. H has no edges.
    static func weighted(_ kind: GraphKind, _ edgeType: EdgeType) throws -> Fixture {
        try Fixture(kind, vertices: ["A", "B", "C", "D", "E", "F", "H"], edgeType, edges: [
            ("A", "B", 7), ("A", "C", 9), ("A", "F", 14),
            ("B", "C", 10), ("B", "D", 15),
            ("C", "D", 11), ("C", "F", 2),
            ("D", "E", 6),
            ("F", "E", 9),
        ])
    }
}

extension Array {
    /// The names of the vertices, in order.
    func names() -> [String] where Element == Vertex<String> {
        map(\.data)
    }

    /// The names of the vertices along a path.
    func names() -> [String] where Element == Edge<String> {
        guard let first else {
            return []
        }
        return [first.source.data] + map(\.destination.data)
    }
}
