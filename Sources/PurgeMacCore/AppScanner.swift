// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Scans the standard macOS application directories for installed apps.
///
/// Apple-provided system apps (those whose bundle identifier starts with
/// `com.apple.`) are intentionally excluded because removing them is neither
/// supported nor safe.
public struct AppScanner {
    public init() {}

    /// Returns all non-system apps found under `/Applications` and
    /// `~/Applications`, sorted by name.
    public func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        for directory in applicationDirectories() {
            let keys: [URLResourceKey] = [.isDirectoryKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: options
            ) else {
                continue
            }

            for entry in entries where entry.pathExtension == "app" {
                if let app = Self.parseApp(at: entry) {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The directories that hold installed applications on a default macOS setup.
    private func applicationDirectories() -> [URL] {
        var directories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true)
        ]

        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        directories.append(homeApplications)

        return directories
    }

    /// Reads the metadata of a single `.app` bundle, filtering out system apps.
    private static func parseApp(at url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let bundleID = bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String ?? ""
        // Never expose Apple system apps for removal.
        if bundleID.hasPrefix("com.apple.") {
            return nil
        }

        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? fallbackName
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let iconPath = Self.iconPath(in: url, bundle: bundle)

        return InstalledApp(
            name: name,
            bundleID: bundleID,
            path: url.path,
            version: version,
            iconPath: iconPath
        )
    }

    /// Resolves the on-disk `.icns` icon path for an app bundle, if present.
    private static func iconPath(in bundleURL: URL, bundle: Bundle) -> String? {
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let fileManager = FileManager.default

        if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            var iconFileName = iconFile
            if !iconFileName.lowercased().hasSuffix(".icns") {
                iconFileName += ".icns"
            }
            let candidate = resourcesURL.appendingPathComponent(iconFileName)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }

        // Fall back to the conventional icon asset name used by Xcode projects.
        let fallback = resourcesURL.appendingPathComponent("AppIcon.icns")
        if fileManager.fileExists(atPath: fallback.path) {
            return fallback.path
        }

        return nil
    }
}
