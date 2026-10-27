// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// The category of junk that can be scanned and cleaned.
public enum JunkCategory: String, Codable, CaseIterable {
    // MARK: - System Junk
    /// Per-user application and system caches under `~/Library/Caches`.
    case userCaches = "caches"
    /// Per-user log files and developer junk under `~/Library/Logs` and related.
    case logs = "logs"
    /// Orphaned files from uninstalled applications.
    case leftovers = "leftovers"
    /// Individual large files under Downloads and Desktop (list-only).
    case largeFiles = "large-files"
    /// The contents of the Trash, cleaned by emptying it.
    case trash = "trash"

    // MARK: - Developer Tools
    /// Xcode derived data, archives, device support, etc.
    case devXcode = "dev-xcode"
    /// Homebrew cache.
    case devHomebrew = "dev-homebrew"
    /// Node.js / npm / yarn / pnpm caches.
    case devNode = "dev-node"
    /// Python / pip / Poetry / conda caches.
    case devPython = "dev-python"
    /// Rust / Cargo caches.
    case devRust = "dev-rust"
    /// Go caches.
    case devGo = "dev-go"
    /// JetBrains IDEs caches.
    case devJetBrains = "dev-jetbrains"
    /// VS Code caches.
    case devVSCode = "dev-vscode"
    /// Docker / OrbStack caches.
    case devContainers = "dev-containers"

    /// A human-readable label for UI and CLI output.
    public var displayName: String {
        switch self {
        case .userCaches: return "User Caches"
        case .logs: return "Logs"
        case .leftovers: return "App Leftovers"
        case .largeFiles: return "Large Files"
        case .trash: return "Trash"
        case .devXcode: return "Xcode"
        case .devHomebrew: return "Homebrew"
        case .devNode: return "Node.js"
        case .devPython: return "Python"
        case .devRust: return "Rust"
        case .devGo: return "Go"
        case .devJetBrains: return "JetBrains"
        case .devVSCode: return "VS Code"
        case .devContainers: return "Containers"
        }
    }
}

/// A single junk item eligible for cleanup.
public struct JunkItem: Codable, Equatable {
    /// The absolute filesystem path.
    public let path: String
    /// The total size in bytes of the file or directory tree.
    public let size: Int64
    /// The junk category this item belongs to.
    public let category: JunkCategory
    /// The last time the item was accessed, if it could be determined.
    public let lastAccessDate: Date?
    /// Whether this item should be selected by default in the UI.
    public let selectedByDefault: Bool

    public init(path: String, size: Int64, category: JunkCategory, lastAccessDate: Date?, selectedByDefault: Bool = true) {
        self.path = path
        self.size = size
        self.category = category
        self.lastAccessDate = lastAccessDate
        self.selectedByDefault = selectedByDefault
    }
}
