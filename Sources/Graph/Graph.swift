import Foundation
import DataStructures

/// TODO: Documentation
public protocol Graph {
  associatedtype Element
  func createVertex(data: Element) -> Vertex<Element>
  func addDirectedEdge(from source: Vertex<Element>, to destination: Vertex<Element>, weight: Double?)
  func addUndirectedEdge(between source: Vertex<Element>, and destination: Vertex<Element>, weight: Double?)
  func add(_ edge: EdgeType, from source: Vertex<Element>, to destination: Vertex<Element>, weight: Double?)
  func edges(from source: Vertex<Element>) -> [Edge<Element>]
  func weight(from source: Vertex<Element>, to destination: Vertex<Element>) -> Double?
}

extension Graph {
    public func addUndirectedEdge(between source: Vertex<Element>,
                                  and destination: Vertex<Element>,
                                  weight: Double?)
    {
        addDirectedEdge(from: source, to: destination, weight: weight)
        addDirectedEdge(from: destination, to: source, weight: weight)
    }
    
    public func add(_ edge: EdgeType,
                    from source: Vertex<Element>,
                    to destination: Vertex<Element>,
                    weight: Double?)
    {
        switch edge {
        case .directed:
            addDirectedEdge(from: source, to: destination, weight: weight)
        case .undirected:
            addUndirectedEdge(between: source, and: destination, weight: weight)
        }
    }
    
}

extension Graph where Element: Hashable {
    func bfs(from source: Vertex<Element>) -> [Vertex<Element>] {
        var queue = QueueStack<Vertex<Element>>()
        var enqueued: Set<Vertex<Element>> = []
        var visited: [Vertex<Element>] = []
        
        _ = queue.enqueue(source)
        enqueued.insert(source)
        while let vertex = queue.dequeue() {
            visited.append(vertex)
            let neighborEdges = edges(from: vertex)
            neighborEdges.forEach { edge in
                if !enqueued.contains(edge.destination) {
                    _ = queue.enqueue(edge.destination)
                    enqueued.insert(edge.destination)
                }
            }
        }
        
        return visited
    }
    
    func dfs(from source: Vertex<Element>) -> [Vertex<Element>] {
        var stack: Stack<Vertex<Element>> = []
        var pushed: Set<Vertex<Element>> = []
        var visited: [Vertex<Element>] = []
        stack.push(source)
        pushed.insert(source)
        visited.append(source)
        
        outer: while let vertex = stack.peek() {
            let neighbors = edges(from: vertex)
        
            guard !neighbors.isEmpty else {
                stack.pop()
                continue
            }
        
            for edge in neighbors {
                if !pushed.contains(edge.destination) {
                    stack.push(edge.destination)
                    pushed.insert(edge.destination)
                    visited.append(edge.destination)
                    continue outer
                }
            }
            stack.pop()
        }
        
        return visited
    }

    func hasCycle(from source: Vertex<Element>) -> Bool  {
      var pushed: Set<Vertex<Element>> = []
      return hasCycle(from: source, pushed: &pushed)
    }
    
    func hasCycle(from source: Vertex<Element>, pushed: inout Set<Vertex<Element>>) -> Bool {
        pushed.insert(source)
        let neighbors = edges(from: source)
        for edge in neighbors {
            if !pushed.contains(edge.destination) &&
                hasCycle(from: edge.destination, pushed: &pushed) {
                return true
            } else if pushed.contains(edge.destination) {
                return true
            }
        }
        pushed.remove(source)
        return false
    }
}

