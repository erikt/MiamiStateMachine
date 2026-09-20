import Testing
import Graph

struct DijkstraTests {

    @Test(arguments: GraphKind.allCases)
    func findsShortestDistances(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .directed)
        let paths = fixture.graph.shortestPaths(from: try fixture.vertex("A"))

        let expected: [String: Double] = ["A": 0, "B": 7, "C": 9, "D": 20, "E": 20, "F": 11]
        for (name, distance) in expected {
            #expect(paths.distance(to: try fixture.vertex(name)) == distance, "Distance to \(name)")
        }
    }

    @Test(arguments: GraphKind.allCases)
    func prefersLowestTotalWeightOverFewestEdges(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .directed)
        let paths = fixture.graph.shortestPaths(from: try fixture.vertex("A"))

        // The direct edge from A to F has the weight 14.
        let toF = try #require(paths.path(to: try fixture.vertex("F")))
        #expect(toF.names() == ["A", "C", "F"])

        let toE = try #require(paths.path(to: try fixture.vertex("E")))
        #expect(toE.names() == ["A", "C", "F", "E"])
        #expect(toE.map(\.weight) == [9, 2, 9])
    }

    @Test(arguments: GraphKind.allCases)
    func pathToSourceIsEmpty(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .directed)
        let a = try fixture.vertex("A")
        let paths = fixture.graph.shortestPaths(from: a)

        #expect(paths.source == a)
        #expect(paths.path(to: a) == [])
        #expect(paths.distance(to: a) == 0)
    }

    @Test(arguments: GraphKind.allCases)
    func unreachableVertexHasNoPath(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .directed)
        let paths = fixture.graph.shortestPaths(from: try fixture.vertex("A"))
        let h = try fixture.vertex("H")

        #expect(paths.path(to: h) == nil)
        #expect(paths.distance(to: h) == nil)
    }

    @Test(arguments: GraphKind.allCases)
    func onlyFollowsEdgeDirection(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .directed)
        let (a, e) = (try fixture.vertex("A"), try fixture.vertex("E"))

        #expect(fixture.graph.shortestPath(from: e, to: a) == nil)
    }

    @Test(arguments: GraphKind.allCases)
    func followsUndirectedEdgesInBothDirections(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .undirected)
        let (a, e) = (try fixture.vertex("A"), try fixture.vertex("E"))

        let path = try #require(fixture.graph.shortestPath(from: e, to: a))
        #expect(path.names() == ["E", "F", "C", "A"])
    }

    @Test(arguments: GraphKind.allCases)
    func shortestPathInUnweightedGraphHasFewestEdges(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], edges: [
            ("A", "B", 1), ("B", "C", 1), ("C", "D", 1), ("A", "C", 1),
        ])
        let (a, d) = (try fixture.vertex("A"), try fixture.vertex("D"))

        let path = try #require(fixture.graph.shortestPath(from: a, to: d))
        #expect(path.names() == ["A", "C", "D"])
    }

    @Test(arguments: GraphKind.allCases)
    func handlesCyclesAndZeroWeights(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C"], edges: [
            ("A", "A", 0), ("A", "B", 0), ("B", "A", 0), ("B", "C", 3), ("A", "C", 4),
        ])
        let (a, c) = (try fixture.vertex("A"), try fixture.vertex("C"))
        let paths = fixture.graph.shortestPaths(from: a)

        #expect(paths.distance(to: c) == 3)
        #expect(paths.path(to: c)?.names() == ["A", "B", "C"])
    }

    @Test func negativeWeightIsProgrammerError() async {
        await #expect(processExitsWith: .failure) {
            var graph = AdjacencyList<String>()
            let a = graph.addVertex("A")
            let b = graph.addVertex("B")
            graph.addDirectedEdge(from: a, to: b, weight: -1)
            _ = graph.shortestPaths(from: a)
        }
    }
}
