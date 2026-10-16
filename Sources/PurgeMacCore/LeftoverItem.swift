// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// The category of a leftover item, keyed by the Library subdirectory it lives in.
public enum LeftoverCategory: String, Codable, CaseIterable {
    case preferences = "Preferences"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case logs = "Logs"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case savedApplicationState = "Saved Application State"

    /// The on-disk directory backing this category.
    var directoryURL: URL {
        let library = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
        switch self {
        case .preferences:
            return library.appendingPathComponent("Preferences", isDirectory: true)
        case .applicationSupport:
            return library.appendingPathComponent("Application Support", isDirectory: true)
        case .caches:
            return library.appendingPathComponent("Caches", isDirectory: true)
        case .logs:
            return library.appendingPathComponent("Logs", isDirectory: true)
        case .containers:
            return library.appendingPathComponent("Containers", isDirectory: true)
        case .groupContainers:
            return library.appendingPathComponent("Group Containers", isDirectory: true)
        case .savedApplicationState:
            return library.appendingPathComponent("Saved Application State", isDirectory: true)
        }
    }
}

/// A single leftover file or directory associated with an uninstalled app.
public struct LeftoverItem: Codable, Equatable {
    /// The absolute filesystem path.
    public let path: String
    /// The total size in bytes of the file or directory tree.
    public let size: Int64
    /// The Library category the item was found in.
    public let category: LeftoverCategory

    public init(path: String, size: Int64, category: LeftoverCategory) {
        self.path = path
        self.size = size
        self.category = category
    }
}
