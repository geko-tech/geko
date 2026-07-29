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

private struct GraphTraversalFrame<Node> {
    let node: Node
    let successors: [Node]
    var nextSuccessorIndex: Int
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

    for node in nodes {
        guard visited.insert(node).inserted else {
            continue
        }

        active.insert(node)
        var stack = [
            GraphTraversalFrame(
                node: node,
                successors: try successors(node),
                nextSuccessorIndex: 0
            ),
        ]

        while !stack.isEmpty {
            let frameIndex = stack.count - 1
            let frame = stack[frameIndex]

            if frame.nextSuccessorIndex < frame.successors.count {
                let successor = frame.successors[frame.nextSuccessorIndex]
                stack[frameIndex].nextSuccessorIndex += 1

                // An edge to an active node closes a cycle in the current DFS path.
                if active.contains(successor) {
                    throw GraphError.unexpectedCycle
                }

                if visited.insert(successor).inserted {
                    active.insert(successor)
                    stack.append(
                        GraphTraversalFrame(
                            node: successor,
                            successors: try successors(successor),
                            nextSuccessorIndex: 0
                        )
                    )
                }
            } else {
                // Append in postorder to preserve the ordering of the recursive implementation.
                result.append(frame.node)
                active.remove(frame.node)
                stack.removeLast()
            }
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

    for node in nodes {
        guard !validNodes.contains(node) else {
            continue
        }

        var path = [node]
        // Mirrors `path` and provides the cycle start index when a back edge is found.
        var activeNodeIndices = [node: 0]
        var stack = [
            GraphTraversalFrame(
                node: node,
                successors: try successors(node),
                nextSuccessorIndex: 0
            ),
        ]

        while !stack.isEmpty {
            let frameIndex = stack.count - 1
            let frame = stack[frameIndex]

            if frame.nextSuccessorIndex < frame.successors.count {
                let successor = frame.successors[frame.nextSuccessorIndex]
                stack[frameIndex].nextSuccessorIndex += 1

                if let cycleStartIndex = activeNodeIndices[successor] {
                    return (
                        path: Array(path[..<cycleStartIndex]),
                        cycle: Array(path[cycleStartIndex...])
                    )
                }

                guard !validNodes.contains(successor) else {
                    continue
                }

                activeNodeIndices[successor] = path.count
                path.append(successor)
                stack.append(
                    GraphTraversalFrame(
                        node: successor,
                        successors: try successors(successor),
                        nextSuccessorIndex: 0
                    )
                )
            } else {
                validNodes.insert(frame.node)
                activeNodeIndices.removeValue(forKey: frame.node)
                path.removeLast()
                stack.removeLast()
            }
        }
    }

    return nil
}
