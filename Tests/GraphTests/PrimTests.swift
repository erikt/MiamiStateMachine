import Testing
import Graph

struct PrimTests {

    /// The undirected edges of a graph, as sorted pairs of vertex names.
    private func undirectedEdges(of graph: some Graph<String>) -> Set<String> {
        Set(graph.vertices.flatMap { vertex in
            graph.edges(from: vertex).map { edge in
                [edge.source.data, edge.destination.data].sorted().joined()
            }
        })
    }

    @Test(arguments: GraphKind.allCases)
    func findsMinimumSpanningTree(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .undirected)
        let (cost, tree) = fixture.graph.minimumSpanningTree()

        #expect(cost == 33)
        #expect(undirectedEdges(of: tree) == ["AB", "AC", "CF", "DE", "EF"])
    }

    @Test(arguments: GraphKind.allCases)
    func treeHasSameVerticesAsGraph(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .undirected)
        let (_, tree) = fixture.graph.minimumSpanningTree()

        #expect(tree.vertices == fixture.graph.vertices)
    }

    @Test(arguments: GraphKind.allCases)
    func treeEdgesAreUndirected(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .undirected)
        let (c, f) = (try fixture.vertex("C"), try fixture.vertex("F"))
        let (_, tree) = fixture.graph.minimumSpanningTree()

        #expect(tree.weight(from: c, to: f) == 2)
        #expect(tree.weight(from: f, to: c) == 2)
    }

    @Test(arguments: GraphKind.allCases)
    func onlySpansVerticesConnectedToFirstVertex(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], .undirected, edges: [
            ("A", "B", 1), ("C", "D", 5),
        ])
        let (cost, tree) = fixture.graph.minimumSpanningTree()

        #expect(cost == 1)
        #expect(undirectedEdges(of: tree) == ["AB"])
    }

    @Test(arguments: GraphKind.allCases)
    func emptyGraphHasEmptyTree(kind: GraphKind) {
        let (cost, tree) = kind.makeGraph().minimumSpanningTree()

        #expect(cost == 0)
        #expect(tree.vertices.isEmpty)
    }
}
