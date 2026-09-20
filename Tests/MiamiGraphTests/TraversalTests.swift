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
    func undirectedEdgeIsCycle(kind: GraphKind) throws {
        let fixture = try Fixture(kind, vertices: ["A", "B"], .undirected, edges: [("A", "B", 1)])

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
            graph.addDirectedEdge(from: top, to: left)
            graph.addDirectedEdge(from: top, to: right)
            graph.addDirectedEdge(from: left, to: bottom)
            graph.addDirectedEdge(from: right, to: bottom)
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
            graph.addDirectedEdge(from: last, to: next)
            last = next
        }

        #expect(graph.hasCycle(reachableFrom: first) == false)

        graph.addDirectedEdge(from: last, to: first)
        #expect(graph.hasCycle(reachableFrom: first))
    }
}
