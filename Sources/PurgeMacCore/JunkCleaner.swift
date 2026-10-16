// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// A single junk item that could not be moved to the Trash.
public struct JunkFailure {
    /// The path that failed to move.
    public let path: String
    /// A human-readable description of why the move failed.
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

/// The outcome of a junk cleanup run.
public struct JunkCleanResult {
    /// Items that were successfully moved to the Trash.
    public let succeeded: [JunkItem]
    /// Items that could not be moved.
    public let failures: [JunkFailure]
    /// Total bytes released by the successfully removed items.
    public let freedBytes: Int64

    public init(succeeded: [JunkItem], failures: [JunkFailure], freedBytes: Int64) {
        self.succeeded = succeeded
        self.failures = failures
        self.freedBytes = freedBytes
    }
}

/// Moves user-selected junk items to the Trash.
public final class JunkCleaner {
    public init() {}

    /// Moves each given item to the Trash, reporting successes and failures.
    ///
    /// Trash contents are emptied by permanently removing them. Large files are
    /// moved to the Trash only when explicitly passed by callers (bulk cleanup
    /// is expected to keep them list-only and exclude them here).
    public func clean(_ items: [JunkItem]) -> JunkCleanResult {
        var succeeded: [JunkItem] = []
        var failures: [JunkFailure] = []
        var freedBytes: Int64 = 0
        let fileManager = FileManager.default

        for item in items {
            let url = URL(fileURLWithPath: item.path)
            do {
                if item.category == .trash {
                    // Emptying the Trash necessarily deletes its contents directly.
                    try fileManager.removeItem(at: url)
                } else {
                    _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
                }
                succeeded.append(item)
                freedBytes += item.size
            } catch {
                failures.append(JunkFailure(path: item.path, reason: error.localizedDescription))
            }
        }

        return JunkCleanResult(succeeded: succeeded, failures: failures, freedBytes: freedBytes)
    }
}
