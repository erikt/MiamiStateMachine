import Testing
import MiamiGraph

struct AdjacencyMatrixTests {

    @Test func addingEdgeAgainReplacesTheFirst() {
        var graph = AdjacencyMatrix<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")

        graph.addDirectedEdge(from: a, to: b, weight: 5)
        graph.addDirectedEdge(from: a, to: b, weight: 3)

        #expect(graph.edges(from: a) == [Edge(source: a, destination: b, weight: 3)])
    }

    @Test func edgesAreOrderedByDestinationIndex() {
        var graph = AdjacencyMatrix<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        let c = graph.addVertex("C")

        graph.addDirectedEdge(from: a, to: c)
        graph.addDirectedEdge(from: a, to: b)

        #expect(graph.edges(from: a).map(\.destination) == [b, c])
    }

    @Test func edgesCanBeAddedBeforeAllVerticesExist() {
        var graph = AdjacencyMatrix<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        graph.addDirectedEdge(from: a, to: b, weight: 2)

        let c = graph.addVertex("C")
        graph.addDirectedEdge(from: c, to: a, weight: 4)

        #expect(graph.weight(from: a, to: b) == 2)
        #expect(graph.weight(from: c, to: a) == 4)
        #expect(graph.weight(from: a, to: c) == nil)
    }

    @Test func describesVerticesAndWeights() {
        var graph = AdjacencyMatrix<String>()
        let a = graph.addVertex("A")
        let b = graph.addVertex("B")
        graph.addDirectedEdge(from: a, to: b, weight: 2)

        #expect(graph.description == "0: A\n1: B\n\nø\t2.0\nø\tø")
    }
}
