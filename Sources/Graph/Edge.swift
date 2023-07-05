import Foundation

/// TODO: Documentation
public enum EdgeType {
    case directed
    case undirected
}

/// TODO: Documentation
public struct Edge<T> {
    public var source: Vertex<T>
    public var destination: Vertex<T>
    public let weight: Double?
}

extension Edge: Equatable where T: Equatable { }

