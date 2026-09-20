import Testing
import MiamiGraph

struct PrimTests {

    /// The vertices connected by the edges of a graph, as sorted pairs of vertex names.
    private func connections(of graph: some Graph<String>) -> Set<String> {
        Set(graph.vertices.flatMap { vertex in
            graph.edges(from: vertex).map { edge in
                [edge.source.data, edge.destination.data].sorted().joined()
            }
        })
    }

    @Test(arguments: GraphKind.allCases)
    func findsMinimumSpanningTree(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .bothWays)
        let (cost, tree) = fixture.graph.minimumSpanningTree()

        #expect(cost == 33)
        #expect(connections(of: tree) == ["AB", "AC", "CF", "DE", "EF"])
    }

    @Test(arguments: GraphKind.allCases)
    func treeHasSameVerticesAsGraph(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .bothWays)
        let (_, tree) = fixture.graph.minimumSpanningTree()

        #expect(tree.vertices == fixture.graph.vertices)
    }

    @Test(arguments: GraphKind.allCases)
    func treeConnectsVerticesInBothDirections(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .bothWays)
        let (c, f) = (try fixture.vertex("C"), try fixture.vertex("F"))
        let (_, tree) = fixture.graph.minimumSpanningTree()

        #expect(tree.lightestEdge(from: c, to: f)?.weight == 2)
        #expect(tree.lightestEdge(from: f, to: c)?.weight == 2)
    }

    @Test(arguments: GraphKind.allCases)
    func onlySpansVerticesConnectedToFirstVertex(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], .bothWays, edges: [
            ("A", "B", 1), ("C", "D", 5),
        ])
        let (cost, tree) = fixture.graph.minimumSpanningTree()

        #expect(cost == 1)
        #expect(connections(of: tree) == ["AB"])
    }

    @Test(arguments: GraphKind.allCases)
    func emptyGraphHasEmptyTree(kind: GraphKind) {
        let (cost, tree) = kind.makeGraph().minimumSpanningTree()

        #expect(cost == 0)
        #expect(tree.vertices.isEmpty)
    }
}
