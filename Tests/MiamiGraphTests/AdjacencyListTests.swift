import Testing
import MiamiGraph

struct AdjacencyListTests {

    @Test func keepsParallelEdges() {
        var graph = AdjacencyList<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")

        graph.addEdge(from: a, to: b, weight: 5)
        graph.addEdge(from: a, to: b, weight: 3)

        #expect(graph.edges(from: a).map(\.weight) == [5, 3])
        #expect(graph.lightestEdge(from: a, to: b)?.weight == 3, "Should be the lowest weight of the parallel edges.")
    }

    @Test func edgesAreInTheOrderAdded() {
        var graph = AdjacencyList<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        let c = graph.addVertex("C")

        graph.addEdge(from: a, to: c)
        graph.addEdge(from: a, to: b)

        #expect(graph.edges(from: a).map(\.destination) == [c, b])
    }

    @Test func describesDestinationsForEachVertex() {
        var graph = AdjacencyList<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        let c = graph.addVertex("C")
        graph.addEdge(from: a, to: b)
        graph.addEdge(from: a, to: c)
        graph.addEdge(from: c, to: a)

        #expect(graph.description == """
            0: A ---> [1: B, 2: C]
            1: B ---> []
            2: C ---> [0: A]
            """)
    }
}
