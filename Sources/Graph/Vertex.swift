import Foundation

/// TODO: Documentation
public struct Vertex<T> {
    public let data: T
    public let index: Int
    
    public init(index: Int, data: T) {
        self.index = index
        self.data = data
    }
}

extension Vertex: Hashable where T: Hashable {}
extension Vertex: Equatable where T: Equatable {}

extension Vertex: CustomStringConvertible {
    public var description: String {
        return "\(index): \(data)"
    }
}
