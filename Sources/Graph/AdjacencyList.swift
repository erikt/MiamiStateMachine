import Foundation

/// TODO: Documentation
public class AdjacencyList<T: Hashable> {
    private var adjacencies: [Vertex<T>: [Edge<T>]] = [:]
    
    public init() {}
    
    public var vertices: [Vertex<T>] {
        Array(adjacencies.keys)
    }
}
    
extension AdjacencyList: Graph {
    public func createVertex(data: T) -> Vertex<T> {
      let vertex = Vertex(index: adjacencies.count, data: data)
      adjacencies[vertex] = []
      return vertex
    }
    
    public func addDirectedEdge(from source: Vertex<T>, to destination: Vertex<T>, weight: Double?) {
        let edge = Edge(source: source, destination: destination, weight: weight)
        adjacencies[source]?.append(edge)
    }
     
    public func edges(from source: Vertex<T>) -> [Edge<T>] {
      return adjacencies[source] ?? []
    }
    
    public func weight(from source: Vertex<T>, to destination: Vertex<T>) -> Double? {
      return edges(from: source).first {
          $0.destination == destination
      }?.weight
    }
    
    public func copyVertices(from graph: AdjacencyList) {
        for vertex in graph.vertices {
            adjacencies[vertex] = []
        }
    }
}

extension AdjacencyList: CustomStringConvertible {
    public var description: String {
        return adjacencies.map { vertex, edges in
            let e = edges.map { "\($0.destination)" }.joined(separator: ", ")
            return "\(vertex) ---> [\(e)]"
        }.joined(separator: "\n")
    }
}
