// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// A user-installed macOS application discovered by `AppScanner`.
public struct InstalledApp: Codable, Equatable {
    /// The friendly display name read from the app bundle.
    public let name: String
    /// The reverse-DNS bundle identifier.
    public let bundleID: String
    /// The absolute filesystem path to the `.app` bundle.
    public let path: String
    /// The short version string, e.g. `1.2.3`.
    public let version: String
    /// The absolute path to the app icon resource, if one could be located.
    public let iconPath: String?

    public init(name: String, bundleID: String, path: String, version: String, iconPath: String?) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.version = version
        self.iconPath = iconPath
    }
}
