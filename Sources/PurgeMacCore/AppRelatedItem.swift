// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// The category of an app-related file for uninstall review.
public enum AppRelatedCategory: String, Codable, CaseIterable {
    case bundle = "Application"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case savedApplicationState = "Saved Application State"
    case logs = "Logs"
    case launchAgents = "Launch Agents"
    case httpStorages = "HTTPStorages"
}

/// A file or folder related to an app, for uninstall review.
public struct AppRelatedItem: Codable, Equatable, Hashable {
    /// The absolute filesystem path.
    public let path: String
    /// The total size in bytes of the file or directory tree.
    public let size: Int64
    /// The category of this item.
    public let category: AppRelatedCategory

    public init(path: String, size: Int64, category: AppRelatedCategory) {
        self.path = path
        self.size = size
        self.category = category
    }
}