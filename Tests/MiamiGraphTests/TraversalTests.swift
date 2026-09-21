import Testing
import MiamiGraph

struct TraversalTests {

    // MARK: - Traversal

    @Test(arguments: GraphKind.allCases)
    func breadthFirstVisitsClosestVerticesFirst(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let visited = fixture.graph.breadthFirstTraversal(from: try fixture.vertex("A"))

        #expect(visited.names() == ["A", "B", "C", "D", "E"])
    }

    @Test(arguments: GraphKind.allCases)
    func depthFirstFollowsEachPathToTheEnd(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let visited = fixture.graph.depthFirstTraversal(from: try fixture.vertex("A"))

        #expect(visited.names() == ["A", "B", "D", "E", "C"])
    }

    @Test(arguments: GraphKind.allCases)
    func traversalOnlyFollowsEdgeDirection(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let d = try fixture.vertex("D")

        #expect(fixture.graph.breadthFirstTraversal(from: d).names() == ["D", "E"])
        #expect(fixture.graph.depthFirstTraversal(from: d).names() == ["D", "E"])
    }

    @Test(arguments: GraphKind.allCases)
    func traversalVisitsVerticesInCycleOnce(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C"], edges: [
            ("A", "A", 1), ("A", "B", 1), ("B", "C", 1), ("C", "A", 1),
        ])
        let a = try fixture.vertex("A")

        #expect(fixture.graph.breadthFirstTraversal(from: a).names() == ["A", "B", "C"])
        #expect(fixture.graph.depthFirstTraversal(from: a).names() == ["A", "B", "C"])
    }

    @Test(arguments: GraphKind.allCases)
    func breadthFirstFromSeveralVerticesVisitsEveryVertexOnce(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let (a, b, c, d) = (try fixture.vertex("A"), try fixture.vertex("B"), try fixture.vertex("C"), try fixture.vertex("D"))

        // D is reached from both B and C.
        #expect(fixture.graph.breadthFirstTraversal(from: [b, c]).names() == ["B", "C", "D", "E"])

        // The sources come first, then what is one edge from any of them.
        #expect(fixture.graph.breadthFirstTraversal(from: [d, a]).names() == ["D", "A", "E", "B", "C"])

        // A source given twice, and a source reached from another source.
        #expect(fixture.graph.breadthFirstTraversal(from: [a, a, b]).names() == ["A", "B", "C", "D", "E"])
    }

    @Test(arguments: GraphKind.allCases)
    func breadthFirstFromNoVerticesVisitsNothing(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)

        #expect(fixture.graph.breadthFirstTraversal(from: []).isEmpty)
    }

    @Test func breadthFirstFromSeveralVerticesAsksForTheEdgesOfEveryVertexOnce() {
        // Every vertex of a chain as a source. Searching from one source at a
        // time would ask for the edges about 500 000 times.
        var graph = CountingGraph<Int>()
        let vertices = (0 ..< 1_000).map { graph.addVertex($0) }
        for (vertex, next) in zip(vertices, vertices.dropFirst()) {
            graph.addEdge(from: vertex, to: next)
        }

        #expect(graph.breadthFirstTraversal(from: vertices).count == 1_000)
        #expect(graph.edgesCallCount == 1_000)
    }

    // MARK: - Path with fewest edges

    @Test(arguments: GraphKind.allCases)
    func pathWithFewestEdgesDoesNotConsiderWeights(kind: GraphKind) throws {
        let fixture = try Fixture.weighted(kind, .oneWay)
        let (a, f) = (try fixture.vertex("A"), try fixture.vertex("F"))

        // The edge from A to F has the weight 14. By way of C the weight is 11.
        #expect(fixture.graph.pathWithFewestEdges(from: a, to: f)?.names() == ["A", "F"])
        #expect(fixture.graph.shortestPath(from: a, to: f)?.names() == ["A", "C", "F"])
    }

    @Test(arguments: GraphKind.allCases)
    func pathWithFewestEdgesFollowsTheDirectionOfTheEdges(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let (a, e) = (try fixture.vertex("A"), try fixture.vertex("E"))

        let path = try #require(fixture.graph.pathWithFewestEdges(from: a, to: e))
        #expect(path.count == 3)
        #expect(path.names().first == "A")
        #expect(path.names().last == "E")
        #expect(["B", "C"].contains(path.names()[1]), "Both ways to D have the same number of edges.")

        #expect(fixture.graph.pathWithFewestEdges(from: e, to: a) == nil)
    }

    @Test(arguments: GraphKind.allCases)
    func pathWithFewestEdgesToTheSourceIsEmpty(kind: GraphKind) throws {
        // Also when edges lead from the vertex back to itself.
        let fixture = try Fixture(kind, vertices: ["A", "B"], edges: [("A", "A", 1), ("A", "B", 1), ("B", "A", 1)])
        let a = try fixture.vertex("A")

        #expect(fixture.graph.pathWithFewestEdges(from: a, to: a) == [])
    }

    @Test(arguments: GraphKind.allCases)
    func vertexNotReachedHasNoPathWithFewestEdges(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)
        let a = try fixture.vertex("A")

        #expect(fixture.graph.pathWithFewestEdges(from: a, to: try fixture.vertex("X")) == nil)
        #expect(fixture.graph.pathWithFewestEdges(from: a, to: Vertex(index: 100, data: "Z")) == nil)
    }

    @Test func searchForPathStopsWhenTheDestinationIsReached() {
        // A long chain, with the destination right after the source.
        var graph = CountingGraph<Int>()
        let vertices = (0 ..< 1_000).map { graph.addVertex($0) }
        for (vertex, next) in zip(vertices, vertices.dropFirst()) {
            graph.addEdge(from: vertex, to: next)
        }

        #expect(graph.pathWithFewestEdges(from: vertices[0], to: vertices[1])?.count == 1)
        #expect(graph.edgesCallCount == 1, "Only the edges of the source should be needed.")
    }

    @Test func pathWithFewestEdgesIsNotLimitedByTheDepthOfTheGraph() {
        var graph = AdjacencyList<Int>()
        let vertices = (0 ..< 100_000).map { graph.addVertex($0) }
        for (vertex, next) in zip(vertices, vertices.dropFirst()) {
            graph.addEdge(from: vertex, to: next)
        }

        #expect(graph.pathWithFewestEdges(from: vertices[0], to: vertices[99_999])?.count == 99_999)
    }

    /// Without weights, the path with the fewest edges and the path with the lowest
    /// weight have the same number of edges. The two are found in different ways,
    /// so they are compared for every pair of vertices in graphs made at random.
    @Test(arguments: [1, 2, 3, 4, 5] as [UInt64])
    func pathWithFewestEdgesIsAsLongAsTheShortestPathWithoutWeights(seed: UInt64) throws {
        var generator = SeededGenerator(seed: seed)

        for _ in 0 ..< 20 {
            var graph = AdjacencyList<Int>()
            let vertices = (0 ..< Int.random(in: 1 ... 25, using: &generator)).map { graph.addVertex($0) }

            // From few edges, leaving vertices out of reach, to many. Edges
            // from a vertex to itself, and several edges the same way, are included.
            for _ in 0 ..< Int.random(in: 0 ... 3 * vertices.count, using: &generator) {
                let source = try #require(vertices.randomElement(using: &generator))
                let destination = try #require(vertices.randomElement(using: &generator))
                graph.addEdge(from: source, to: destination)
            }

            for source in vertices {
                for destination in vertices {
                    let path = graph.pathWithFewestEdges(from: source, to: destination)
                    let shortestPath = graph.shortestPath(from: source, to: destination)
                    try #require(path?.count == shortestPath?.count, "From \(source) to \(destination) in:\n\(graph)")

                    guard let path, let first = path.first, let last = path.last else {
                        continue
                    }

                    // The path leads all the way, by edges of the graph.
                    try #require(first.source == source && last.destination == destination)
                    for (edge, next) in zip(path, path.dropFirst()) {
                        try #require(edge.destination == next.source)
                    }
                    for edge in path {
                        try #require(graph.edges(from: edge.source).contains(edge))
                    }
                }
            }
        }
    }

    // MARK: - Cycle detection

    @Test(arguments: GraphKind.allCases)
    func twoPathsToSameVertexIsNotCycle(kind: GraphKind) throws {
        let fixture = try Fixture.diamond(kind)

        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("A")) == false)
        #expect(fixture.graph.hasCycle == false)
    }

    @Test(arguments: GraphKind.allCases)
    func findsCycle(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], edges: [
            ("A", "B", 1), ("B", "C", 1), ("C", "D", 1), ("D", "B", 1),
        ])

        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("A")))
        #expect(fixture.graph.hasCycle)
    }

    @Test(arguments: GraphKind.allCases)
    func edgeFromVertexToItselfIsCycle(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A"], edges: [("A", "A", 1)])

        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("A")))
        #expect(fixture.graph.hasCycle)
    }

    @Test(arguments: GraphKind.allCases)
    func verticesConnectedInBothDirectionsAreCycle(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], .bothWays, edges: [("A", "B", 1)])

        #expect(fixture.graph.hasCycle)
    }

    @Test(arguments: GraphKind.allCases)
    func cycleNotReachableFromVertexIsOnlyFoundInWholeGraph(kind: GraphKind) throws {
        // The first vertex leads to B, but not to the cycle between C and D. A
        // search of the whole graph has to continue from more than the first vertex.
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], edges: [
            ("A", "B", 1), ("C", "D", 1), ("D", "C", 1),
        ])

        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("A")) == false)
        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("C")))
        #expect(fixture.graph.hasCycle)
    }

    @Test(arguments: GraphKind.allCases)
    func cycleLeadingToVertexIsNotReachableFromIt(kind: GraphKind) throws {
        // The cycle between A and B leads to C, but not the other way around.
        let fixture = try Fixture(kind, vertices: ["A", "B", "C", "D"], edges: [
            ("A", "B", 1), ("B", "A", 1), ("B", "C", 1), ("C", "D", 1),
        ])

        #expect(fixture.graph.hasCycle(reachableFrom: try fixture.vertex("C")) == false)
        #expect(fixture.graph.hasCycle)
    }

    @Test(arguments: GraphKind.allCases)
    func emptyGraphHasNoCycle(kind: GraphKind) {
        #expect(kind.makeGraph().hasCycle == false)
    }

    @Test func cycleSearchAsksForTheEdgesOfEveryVertexOnce() {
        // A chain of 12 diamonds has 4 096 different paths from the first to the
        // last vertex. A search following every path, and not remembering the
        // vertices already searched, asks for the edges thousands of times.
        var graph = CountingGraph<Int>()
        var top = graph.addVertex(0)
        let first = top
        for _ in 0 ..< 12 {
            let left = graph.addVertex(0)
            let right = graph.addVertex(0)
            let bottom = graph.addVertex(0)
            graph.addEdge(from: top, to: left)
            graph.addEdge(from: top, to: right)
            graph.addEdge(from: left, to: bottom)
            graph.addEdge(from: right, to: bottom)
            top = bottom
        }

        #expect(graph.hasCycle(reachableFrom: first) == false)
        #expect(graph.edgesCallCount == graph.vertices.count)
    }

    @Test func cycleSearchIsNotLimitedByTheDepthOfTheGraph() {
        // Tests do not run on the main thread, and other threads have small
        // stacks. A recursive search of a chain this long ends in a crash.
        //
        // Only the search from a vertex is used here. A chain has a single
        // path, so the test is fast even for a search doing too much work.
        var graph = AdjacencyList<Int>()
        var last = graph.addVertex(0)
        let first = last
        for number in 1 ..< 100_000 {
            let next = graph.addVertex(number)
            graph.addEdge(from: last, to: next)
            last = next
        }

        #expect(graph.hasCycle(reachableFrom: first) == false)

        graph.addEdge(from: last, to: first)
        #expect(graph.hasCycle(reachableFrom: first))
    }
}
