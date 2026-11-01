// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// A single related item that could not be moved to the Trash.
public struct AppRelatedFailure {
    /// The path that failed to move.
    public let path: String
    /// A human-readable description of why the move failed.
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

/// The outcome of an app-related cleanup run.
public struct AppRelatedCleanResult {
    /// Items that were successfully moved to the Trash.
    public let succeeded: [AppRelatedItem]
    /// Items that could not be moved.
    public let failures: [AppRelatedFailure]
    /// Total bytes released by the successfully removed items.
    public let freedBytes: Int64

    public init(succeeded: [AppRelatedItem], failures: [AppRelatedFailure], freedBytes: Int64) {
        self.succeeded = succeeded
        self.failures = failures
        self.freedBytes = freedBytes
    }
}

/// Moves user-selected app-related items to the Trash.
public final class AppRelatedCleaner {
    public init() {}

    /// Moves each given item to the Trash, reporting successes and failures.
    public func clean(_ items: [AppRelatedItem]) -> AppRelatedCleanResult {
        var succeeded: [AppRelatedItem] = []
        var failures: [AppRelatedFailure] = []
        var freedBytes: Int64 = 0
        let fileManager = FileManager.default

        for item in items {
            let url = URL(fileURLWithPath: item.path)
            do {
                _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
                succeeded.append(item)
                freedBytes += item.size
            } catch {
                failures.append(AppRelatedFailure(path: item.path, reason: error.localizedDescription))
            }
        }

        return AppRelatedCleanResult(succeeded: succeeded, failures: failures, freedBytes: freedBytes)
    }
}