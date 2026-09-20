import Testing
import Graph

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

    @Test func cycleSearchIsFastWithManyPathsToSameVertices() throws {
        // A chain of 40 diamonds has 2^40 different paths from the
        // first to the last vertex. Every vertex should only be searched once.
        var graph = AdjacencyList<Int>()
        var top = graph.addVertex(0)
        let first = top
        for _ in 0 ..< 40 {
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
    }
}
