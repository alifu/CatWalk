//
//  CWMemoryBudget.swift
//  CatWalk
//

/// Running total of captured body bytes against an upper bound.
struct CWMemoryBudget: Sendable, Equatable {

    var maxTotalBodyBytes: Int

    private(set) var totalBodyBytes = 0

    init(maxTotalBodyBytes: Int) {
        self.maxTotalBodyBytes = max(0, maxTotalBodyBytes)
    }

    var isOverBudget: Bool {
        totalBodyBytes > maxTotalBodyBytes
    }

    mutating func add(_ bytes: Int) {
        totalBodyBytes += bytes
    }

    mutating func remove(_ bytes: Int) {
        totalBodyBytes = max(0, totalBodyBytes - bytes)
    }

    mutating func reset() {
        totalBodyBytes = 0
    }
}
