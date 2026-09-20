import Testing
import MiamiGraph

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
    func edgeLeadsInOneDirection(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], edges: [("A", "B", 2.5)])
        let (a, b) = (try fixture.vertex("A"), try fixture.vertex("B"))

        #expect(fixture.graph.edges(from: a) == [Edge(source: a, destination: b, weight: 2.5)])
        #expect(fixture.graph.edges(from: b).isEmpty)
    }

    @Test(arguments: GraphKind.allCases)
    func lightestEdgeLeadsDirectlyFromVertexToAnother(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C"], edges: [("A", "B", 2), ("B", "C", 3), ("C", "C", 4)])
        let (a, b, c) = (try fixture.vertex("A"), try fixture.vertex("B"), try fixture.vertex("C"))

        #expect(fixture.graph.lightestEdge(from: a, to: b) == Edge(source: a, destination: b, weight: 2))
        #expect(fixture.graph.lightestEdge(from: c, to: c) == Edge(source: c, destination: c, weight: 4))
        #expect(fixture.graph.lightestEdge(from: b, to: a) == nil, "The edge leads the other way.")
        #expect(fixture.graph.lightestEdge(from: a, to: c) == nil, "C is two edges from A.")
    }

    @Test(arguments: GraphKind.allCases)
    func edgesBetweenVerticesLeadInBothDirections(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], .bothWays, edges: [("A", "B", 2.5)])
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

        graph.addEdge(from: a, to: b)
        graph.addEdges(between: b, and: c)

        #expect(graph.lightestEdge(from: a, to: b)?.weight == 1)
        #expect(graph.lightestEdge(from: b, to: c)?.weight == 1)
        #expect(graph.lightestEdge(from: c, to: b)?.weight == 1)
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
        copy.addEdge(from: a, to: b)

        #expect(original.graph.vertices.count == 2)
        #expect(original.graph.edges(from: a).isEmpty)
        #expect(copy.vertices.count == 3)
        #expect(copy.edges(from: a).count == 1)
    }

    @Test(arguments: GraphKind.allCases)
    func describesItsEdgesAndVerticesWithoutEdges(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C"], edges: [
            ("A", "B", 1), ("A", "C", 2.5), ("C", "A", 1),
        ])

        #expect("\(fixture.graph)" == """
            0: A --(1.0)--> 1: B
            0: A --(2.5)--> 2: C
            1: B
            2: C --(1.0)--> 0: A
            """)
        #expect("\(kind.makeGraph())" == "")
    }

    // MARK: - Programmer errors

    // Exit tests only exist on the platforms below. Without the condition,
    // the tests of the package would not build for iOS and the other platforms.
    //
    // The tests verify that the process stops. They cannot tell a failed
    // precondition of the graph from any other reason to stop.
    #if os(macOS) || os(Linux) || os(Windows)
    @Test(arguments: GraphKind.allCases)
    func addingEdgeToUnknownVertexIsProgrammerError(kind: GraphKind) async {
        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            let a = graph.addVertex("A")
            graph.addEdge(from: a, to: Vertex(index: 1, data: "B"))
        }
    }

    @Test(arguments: GraphKind.allCases)
    func addingEdgeFromUnknownVertexIsProgrammerError(kind: GraphKind) async {
        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            let a = graph.addVertex("A")
            graph.addEdge(from: Vertex(index: 1, data: "B"), to: a)
        }
    }

    @Test(arguments: GraphKind.allCases)
    func weightThatIsNotFiniteIsProgrammerError(kind: GraphKind) async {
        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            let a = graph.addVertex("A")
            let b = graph.addVertex("B")
            graph.addEdge(from: a, to: b, weight: .infinity)
        }

        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            let a = graph.addVertex("A")
            let b = graph.addVertex("B")
            graph.addEdge(from: a, to: b, weight: .nan)
        }
    }

    @Test(arguments: GraphKind.allCases)
    func edgesFromUnknownVertexIsProgrammerError(kind: GraphKind) async {
        await #expect(processExitsWith: .failure) { [kind] in
            var graph = kind.makeGraph()
            graph.addVertex("A")
            _ = graph.edges(from: Vertex(index: 1, data: "B"))
        }
    }
    #endif
}
