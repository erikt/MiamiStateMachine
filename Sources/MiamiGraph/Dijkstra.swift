import MiamiDataStructures

/// The shortest paths from a source vertex to all
/// other vertices in a graph.
package struct ShortestPaths<Element> {

    /// The vertex all paths start from.
    package let source: Vertex<Element>

    /// Distance from the source to each vertex, by vertex
    /// index. Infinity for vertices which cannot be reached.
    private let distances: [Double]

    /// The last edge of the shortest path to each vertex, by vertex index.
    private let incomingEdges: [Edge<Element>?]

    fileprivate init(source: Vertex<Element>, distances: [Double], incomingEdges: [Edge<Element>?]) {
        self.source = source
        self.distances = distances
        self.incomingEdges = incomingEdges
    }

    /// The total weight of the shortest path from the source to a vertex.
    /// - Parameter destination: The vertex the path leads to.
    /// - Returns: The distance, or `nil` if the vertex cannot be reached
    /// from the source. The distance to the source itself is zero.
    package func distance(to destination: Vertex<Element>) -> Double? {
        guard distances.indices.contains(destination.index),
              distances[destination.index].isFinite
        else {
            return nil
        }
        return distances[destination.index]
    }

    /// The shortest path from the source to a vertex.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// - Parameter destination: The vertex the path leads to.
    /// - Returns: The edges to follow from the source, or `nil` if the vertex
    /// cannot be reached from the source. The path to the source itself is empty.
    package func path(to destination: Vertex<Element>) -> [Edge<Element>]? {
        guard distance(to: destination) != nil else {
            return nil
        }

        var path: [Edge<Element>] = []
        var index = destination.index
        while let edge = incomingEdges[index] {
            path.append(edge)
            index = edge.source.index
        }
        return path.reversed()
    }
}

extension ShortestPaths: Sendable where Element: Sendable {}

extension Graph {

    /// Finds the shortest paths from a vertex to all other vertices,
    /// using Dijkstra's algorithm.
    ///
    /// The shortest path is the path with the lowest total weight. In an
    /// unweighted graph this is the path with the fewest edges.
    /// - Parameter source: The vertex all paths start from.
    /// - Returns: The shortest paths from the source.
    /// - Precondition: No edge reachable from the source has a negative weight.
    /// - Complexity: O((*V* + *E*) log *V*) for an adjacency list, where *V* is
    /// the number of vertices and *E* the number of edges.
    package func shortestPaths(from source: Vertex<Element>) -> ShortestPaths<Element> {
        var distances = [Double](repeating: .infinity, count: vertices.count)
        var incomingEdges = [Edge<Element>?](repeating: nil, count: vertices.count)
        // Vertices to continue from, the one closest to the source first.
        var queue = PriorityQueue<Prioritized<Vertex<Element>, Double>>()

        distances[source.index] = 0
        queue.enqueue(Prioritized(source, priority: 0))

        while let closest = queue.dequeue() {
            let (vertex, distance) = (closest.value, closest.priority)

            guard distance <= distances[vertex.index] else {
                // A shorter path to the vertex was found
                // after this entry was enqueued.
                continue
            }

            for edge in edges(from: vertex) {
                precondition(edge.weight >= 0, "Dijkstra's algorithm cannot handle negative weights.")

                let candidate = distance + edge.weight
                if candidate < distances[edge.destination.index] {
                    distances[edge.destination.index] = candidate
                    incomingEdges[edge.destination.index] = edge
                    queue.enqueue(Prioritized(edge.destination, priority: candidate))
                }
            }
        }

        return ShortestPaths(source: source, distances: distances, incomingEdges: incomingEdges)
    }

    /// Finds the shortest path from a vertex to another vertex.
    ///
    /// Use `shortestPaths(from:)` when looking for the paths to
    /// more than one destination from the same source.
    /// - Parameters:
    ///   - source: The vertex the path starts from.
    ///   - destination: The vertex the path leads to.
    /// - Returns: The edges to follow from the source, or `nil` if the destination
    /// cannot be reached from the source. The path to the source itself is empty.
    /// - Precondition: No edge reachable from the source has a negative weight.
    package func shortestPath(from source: Vertex<Element>,
                              to destination: Vertex<Element>) -> [Edge<Element>]?
    {
        shortestPaths(from: source).path(to: destination)
    }
}
