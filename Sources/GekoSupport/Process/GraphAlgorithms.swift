/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public enum GraphError: Error {
    /// A cycle was detected in the input.
    case unexpectedCycle
}

/// Compute the transitive closure of an input node set.
///
/// - Note: The relation is *not* assumed to be reflexive; i.e. the result will
///         not automatically include `nodes` unless present in the relation defined by
///         `successors`.
public func transitiveClosure<T>(
    _ nodes: [T], successors: (T) throws -> [T]
) rethrows -> Set<T> {
    var result = Set<T>()

    // The queue of items to recursively visit.
    //
    // We add items post-collation to avoid unnecessary queue operations.
    var queue = nodes
    while let node = queue.popLast() {
        for succ in try successors(node) {
            if result.insert(succ).inserted {
                queue.append(succ)
            }
        }
    }

    return result
}

/// Perform a topological sort of an graph.
///
/// This function is optimized for use cases where cycles are unexpected, and
/// does not attempt to retain information on the exact nodes in the cycle.
///
/// - Parameters:
///   - nodes: The list of input nodes to sort.
///   - successors: A closure for fetching the successors of a particular node.
///
/// - Returns: A list of the transitive closure of nodes reachable from the
/// inputs, ordered such that every node in the list follows all of its
/// predecessors.
///
/// - Throws: GraphError.unexpectedCycle
///
/// - Complexity: O(v + e) where (v, e) are the number of vertices and edges
/// reachable from the input nodes via the relation.
public func topologicalSort<T: Hashable>(
    _ nodes: [T], successors: (T) throws -> [T]
) throws -> [T] {
    var visited = Set<T>()
    var active = Set<T>()
    var result: [T] = []

    var stack: [(node: T, preOrderVisit: Bool)] = []
    // populate stack in the reverse order to keep original ordering
    for i in stride(from: nodes.count - 1, through: 0, by: -1) {
        stack.append((
            node: nodes[i],
            preOrderVisit: true
        ))
    }

    while !stack.isEmpty {
        let frameIndex = stack.count - 1
        let frame = stack[frameIndex]

        if frame.preOrderVisit {
            guard visited.insert(frame.node).inserted else {
                stack.removeLast()
                continue
            }

            stack[frameIndex].preOrderVisit = false
            active.insert(frame.node)

            let successors = try successors(frame.node)
            // add successors to stack in reverse order to keep tree traversing order the same as successor list
            for i in stride(from: successors.count - 1, through: 0, by: -1) {
                // An edge to an active node closes a cycle in the current DFS path.
                if active.contains(successors[i]) {
                    throw GraphError.unexpectedCycle
                }

                stack.append((node: successors[i], preOrderVisit: true))
            }
        } else {
            // Append in postorder to preserve the ordering of the recursive implementation.
            result.append(frame.node)
            active.remove(frame.node)
            stack.removeLast()
        }
    }

    return result.reversed()
}

/// Finds the first cycle encountered in a graph.
///
/// This method uses DFS to look for a cycle and immediately returns when a
/// cycle is encounted.
///
/// - Parameters:
///   - nodes: The list of input nodes to sort.
///   - successors: A closure for fetching the successors of a particular node.
///
/// - Returns: nil if a cycle is not found or a tuple with the path to the start of the cycle and the cycle itself.
public func findCycle<T: Hashable>(
    _ nodes: [T],
    successors: (T) throws -> [T]
) rethrows -> (path: [T], cycle: [T])? {
    var validNodes = Set<T>()
    var path: [T] = []
    // Mirrors `path` and provides the cycle start index when a back edge is found.
    var activeNodeIndices: [T: Int] = [:]

    var stack: [(node: T, preOrderVisit: Bool)] = []
    // populate stack in the reverse order to keep original ordering
    for i in stride(from: nodes.count - 1, through: 0, by: -1) {
        stack.append((
            node: nodes[i],
            preOrderVisit: true
        ))
    }

    while !stack.isEmpty {
        let frameIndex = stack.count - 1
        let frame = stack[frameIndex]

        if frame.preOrderVisit {
            guard !validNodes.contains(frame.node) else {
                stack.removeLast()
                continue
            }

            stack[frameIndex].preOrderVisit = false
            activeNodeIndices[frame.node] = path.count
            path.append(frame.node)

            let successors = try successors(frame.node)
            for i in stride(from: successors.count - 1, through: 0, by: -1) {
                let successor = successors[i]

                if let cycleStartIndex = activeNodeIndices[successor] {
                    return (
                        path: Array(path[..<cycleStartIndex]),
                        cycle: Array(path[cycleStartIndex...])
                    )
                }

                guard !validNodes.contains(successor) else { continue }

                stack.append((node: successor, preOrderVisit: true))
            }
        } else {
            validNodes.insert(frame.node)
            activeNodeIndices.removeValue(forKey: frame.node)
            path.removeLast()
            stack.removeLast()
        }
    }

    return nil
}
