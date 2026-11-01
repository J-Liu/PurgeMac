// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// A single junk item that could not be moved to the Trash.
public struct JunkFailure {
    /// The path that failed to move.
    public let path: String
    /// A human-readable description of why the move failed.
    public let reason: String
    /// Whether the failure is due to permission issues (can retry with admin).
    public var isPermissionError: Bool

    public init(path: String, reason: String, isPermissionError: Bool = false) {
        self.path = path
        self.reason = reason
        self.isPermissionError = isPermissionError
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
    public func clean(_ items: [JunkItem]) -> JunkCleanResult {
        var succeeded: [JunkItem] = []
        var failures: [JunkFailure] = []
        var freedBytes: Int64 = 0
        let fileManager = FileManager.default

        for item in items {
            let url = URL(fileURLWithPath: item.path)
            do {
                if item.category == .trash {
                    try fileManager.removeItem(at: url)
                } else {
                    _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
                }
                succeeded.append(item)
                freedBytes += item.size
            } catch {
                let isPermissionError = Self.isPermissionError(error)
                failures.append(JunkFailure(
                    path: item.path,
                    reason: error.localizedDescription,
                    isPermissionError: isPermissionError
                ))
            }
        }

        return JunkCleanResult(succeeded: succeeded, failures: failures, freedBytes: freedBytes)
    }

    /// Moves items to Trash using administrator privileges via osascript.
    /// This prompts the user for their password each time.
    public func cleanWithAdminPrivileges(_ items: [JunkItem]) -> JunkCleanResult {
        var succeeded: [JunkItem] = []
        var failures: [JunkFailure] = []
        var freedBytes: Int64 = 0

        for item in items {
            let escapedPath = item.path.replacingOccurrences(of: "'", with: "'\\''")
            // Use a more robust deletion: clear flags and xattrs, then remove
            let script = "do shell script \"chflags -R nouchg,noschg '\(escapedPath)' 2>/dev/null; xattr -cr '\(escapedPath)' 2>/dev/null; rm -rf '\(escapedPath)' 2>&1\" with administrator privileges"

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            let pipe = Pipe()
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    succeeded.append(item)
                    freedBytes += item.size
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

                    // Check for protected container error
                    let isProtectedContainer = errorMessage.contains("containermanagerd.metadata.plist") ||
                                                (errorMessage.contains("Operation not permitted") &&
                                                 item.path.contains("/Containers/"))

                    let reason: String
                    if isProtectedContainer {
                        reason = "Protected by macOS. Restart in Recovery Mode (Cmd+R) to delete, or use a signed cleanup app."
                    } else {
                        reason = errorMessage.isEmpty ? "Command failed with exit code \(task.terminationStatus)" : errorMessage
                    }

                    failures.append(JunkFailure(
                        path: item.path,
                        reason: reason,
                        isPermissionError: !isProtectedContainer
                    ))
                }
            } catch {
                failures.append(JunkFailure(
                    path: item.path,
                    reason: error.localizedDescription,
                    isPermissionError: false
                ))
            }
        }

        return JunkCleanResult(succeeded: succeeded, failures: failures, freedBytes: freedBytes)
    }

    /// Checks if an error is related to permissions.
    private static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code

        // NSFileManager errors
        if domain == NSCocoaErrorDomain {
            switch code {
            case NSFileNoSuchFileError,
                 NSFileLockingError,
                 NSFileReadNoPermissionError,
                 NSFileWriteNoPermissionError:
                return true
            default:
                break
            }
        }

        // Check error description for permission keywords
        let description = error.localizedDescription.lowercased()
        return description.contains("permission") || description.contains("access")
    }
}