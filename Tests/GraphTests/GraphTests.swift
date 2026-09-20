import Testing
import Graph

/// Behavior shared by all graph implementations.
struct GraphTests {

    @Test(arguments: GraphKind.allCases)
    func verticesAreIndexedInTheOrderAdded(kind: GraphKind) {
        var graph = kind.makeGraph()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        let c = graph.addVertex("C")

        #expect(graph.vertices == [a, b, c])
        #expect(graph.vertices.map(\.index) == [0, 1, 2])
    }

    @Test(arguments: GraphKind.allCases)
    func directedEdgeLeadsInOneDirection(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], edges: [("A", "B", 2.5)])
        let (a, b) = (try fixture.vertex("A"), try fixture.vertex("B"))

        #expect(fixture.graph.edges(from: a) == [Edge(source: a, destination: b, weight: 2.5)])
        #expect(fixture.graph.edges(from: b).isEmpty)
        #expect(fixture.graph.weight(from: a, to: b) == 2.5)
        #expect(fixture.graph.weight(from: b, to: a) == nil)
    }

    @Test(arguments: GraphKind.allCases)
    func undirectedEdgeLeadsInBothDirections(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], .undirected, edges: [("A", "B", 2.5)])
        let (a, b) = (try fixture.vertex("A"), try fixture.vertex("B"))

        #expect(fixture.graph.edges(from: a) == [Edge(source: a, destination: b, weight: 2.5)])
        #expect(fixture.graph.edges(from: b) == [Edge(source: b, destination: a, weight: 2.5)])
    }

    @Test(arguments: GraphKind.allCases)
    func unweightedEdgesHaveWeightOne(kind: GraphKind) {
        var graph = kind.makeGraph()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        let c = graph.addVertex("C")

        graph.addDirectedEdge(from: a, to: b)
        graph.addUndirectedEdge(between: b, and: c)
        graph.add(.directed, from: c, to: a)

        #expect(graph.weight(from: a, to: b) == 1)
        #expect(graph.weight(from: c, to: b) == 1)
        #expect(graph.weight(from: c, to: a) == 1)
    }

    @Test(arguments: GraphKind.allCases)
    func edgeFromVertexToItselfIsAllowed(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A"], edges: [("A", "A", 1)])
        let a = try fixture.vertex("A")

        #expect(fixture.graph.edges(from: a) == [Edge(source: a, destination: a)])
    }

    @Test(arguments: GraphKind.allCases)
    func findsFirstVertexHoldingValue(kind: GraphKind) {
        var graph = kind.makeGraph()
        graph.addVertex("A")
        let first = graph.addVertex("B")
        graph.addVertex("B")

        #expect(graph.firstVertex(holding: "B") == first)
        #expect(graph.firstVertex(holding: "C") == nil)
    }

    @Test(arguments: GraphKind.allCases)
    func containsOnlyVerticesWithinBounds(kind: GraphKind) {
        var graph = kind.makeGraph()
        let a = graph.addVertex("A")

        #expect(graph.contains(a))
        #expect(graph.contains(Vertex(index: 1, data: "B")) == false)
    }

    @Test(arguments: GraphKind.allCases)
    func copyIsIndependentOfOriginal(kind: GraphKind) throws {
        let original = try Fixture(kind, vertices: ["A", "B"])
        let (a, b) = (try original.vertex("A"), try original.vertex("B"))

        var copy = original.graph
        copy.addVertex("C")
        copy.addDirectedEdge(from: a, to: b)

        #expect(original.graph.vertices.count == 2)
        #expect(original.graph.edges(from: a).isEmpty)
        #expect(copy.vertices.count == 3)
        #expect(copy.edges(from: a).count == 1)
    }

    @Test(arguments: GraphKind.allCases)
    func addingEdgeToUnknownVertexIsProgrammerError(kind: GraphKind) async {
        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            let a = graph.addVertex("A")
            graph.addDirectedEdge(from: a, to: Vertex(index: 1, data: "B"))
        }
    }
}
