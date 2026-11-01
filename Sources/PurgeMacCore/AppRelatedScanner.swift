// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Scans for files related to a specific installed app for uninstall review.
/// Uses strict matching: bundle ID anchoring is exact; name anchoring requires the whole name.
public struct AppRelatedScanner {

    public init() {}

    /// A location to scan for app-related files, tagged with its category.
    private struct ScanRoot {
        let url: URL
        let category: AppRelatedCategory
    }

    /// Scans for files related to the given app.
    /// - Parameters:
    ///   - bundleID: The app's bundle identifier (e.g., "com.vendor.App")
    ///   - appName: The app's display name (e.g., "My App")
    ///   - appPath: The app bundle path (will be included as the first item)
    /// - Returns: Array of related items found, with app bundle first.
    public func scan(bundleID: String, appName: String, appPath: String) -> [AppRelatedItem] {
        var matches: [(url: URL, category: AppRelatedCategory)] = []
        var seen = Set<String>()

        let lowerBundleID = bundleID.lowercased()
        let lowerAppName = appName.lowercased()
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Include the app bundle itself first
        let appURL = URL(fileURLWithPath: appPath)
        let key = appURL.standardizedFileURL.path
        seen.insert(key)
        matches.append((url: appURL, category: .bundle))

        // Scan each root location
        for root in scanRoots(home: home) {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let name = entry.lastPathComponent
                guard matchReason(
                    forLeftoverName: name,
                    category: root.category,
                    bundleID: lowerBundleID,
                    appName: lowerAppName
                ) != nil else { continue }

                let key = entry.standardizedFileURL.path
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                matches.append((url: entry, category: root.category))
            }
        }

        // Discover sandboxed containers (UUID-named)
        let containerMatches = discoverContainers(bundleID: bundleID, home: home)
        for containerURL in containerMatches {
            let key = containerURL.standardizedFileURL.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            matches.append((url: containerURL, category: .containers))
        }

        // Compute sizes and build results
        var items: [AppRelatedItem] = matches.map { match in
            let size = Self.size(of: match.url)
            return AppRelatedItem(path: match.url.path, size: size, category: match.category)
        }

        // Sort by size (largest first), but keep app bundle at the top
        let appItem = items.removeFirst()
        items.sort { $0.size > $1.size }
        items.insert(appItem, at: 0)

        return items
    }

    /// Kind of match for a related file.
    private enum MatchKind {
        case bundleID    // Exact bundle ID match
        case groupID     // Group container with bundle ID suffix
        case appName     // Name match (needs verification)
    }

    /// Determines if a file name belongs to the app.
    /// - Returns: The kind of match, or nil if no match.
    private func matchReason(
        forLeftoverName name: String,
        category: AppRelatedCategory,
        bundleID: String,
        appName: String
    ) -> MatchKind? {
        let lowerName = name.lowercased()

        // Bundle ID anchored matches
        if !bundleID.isEmpty {
            // Exact bundle ID
            if lowerName == bundleID { return .bundleID }

            // Bundle ID with known extensions
            if lowerName == bundleID + ".plist" { return .bundleID }
            if lowerName == bundleID + ".savedstate" { return .bundleID }
            if lowerName == bundleID + ".binarycookies" { return .bundleID }

            // Launch agents: com.vendor.App.helper.plist
            if category == .launchAgents {
                if lowerName.hasPrefix(bundleID + ".") && lowerName.hasSuffix(".plist") {
                    return .bundleID
                }
            }

            // Group containers: <teamID>.<bundleID> or group.<bundleID>
            if category == .groupContainers {
                if lowerName.hasSuffix("." + bundleID) { return .groupID }
            }
        }

        // Name-only match - only in specific categories
        if category == .applicationSupport || category == .logs {
            if lowerName == appName { return .appName }
        }

        return nil
    }

    /// Locations to scan for app-related files.
    private func scanRoots(home: URL) -> [ScanRoot] {
        let lib = home.appendingPathComponent("Library", isDirectory: true)
        return [
            ScanRoot(url: lib.appendingPathComponent("Application Support", isDirectory: true),
                     category: .applicationSupport),
            ScanRoot(url: lib.appendingPathComponent("Caches", isDirectory: true),
                     category: .caches),
            ScanRoot(url: lib.appendingPathComponent("HTTPStorages", isDirectory: true),
                     category: .httpStorages),
            ScanRoot(url: lib.appendingPathComponent("Preferences", isDirectory: true),
                     category: .preferences),
            ScanRoot(url: lib.appendingPathComponent("Containers", isDirectory: true),
                     category: .containers),
            ScanRoot(url: lib.appendingPathComponent("Group Containers", isDirectory: true),
                     category: .groupContainers),
            ScanRoot(url: lib.appendingPathComponent("Saved Application State", isDirectory: true),
                     category: .savedApplicationState),
            ScanRoot(url: lib.appendingPathComponent("Logs", isDirectory: true),
                     category: .logs),
            ScanRoot(url: lib.appendingPathComponent("LaunchAgents", isDirectory: true),
                     category: .launchAgents),
            ScanRoot(url: URL(fileURLWithPath: "/Library/Application Support", isDirectory: true),
                     category: .applicationSupport),
            ScanRoot(url: URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
                     category: .launchAgents)
        ]
    }

    /// Discovers sandboxed app containers (both named and UUID-based).
    private func discoverContainers(bundleID: String, home: URL) -> [URL] {
        var containers: [URL] = []
        let containersPath = home.appendingPathComponent("Library/Containers", isDirectory: true)

        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: containersPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return containers }

        let lowerBundleID = bundleID.lowercased()

        for dir in dirs {
            let dirName = dir.lastPathComponent

            // Named container matching bundle ID directly
            if dirName.lowercased() == lowerBundleID {
                containers.append(dir)
                continue
            }

            // UUID-named containers: read metadata plist
            if dirName.count == 36 && dirName.contains("-") {
                let metaPlist = dir.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                if let meta = NSDictionary(contentsOf: metaPlist),
                   let containerBundleID = meta["MCMMetadataIdentifier"] as? String,
                   containerBundleID.lowercased() == lowerBundleID {
                    containers.append(dir)
                }
            }
        }

        return containers
    }

    /// Recursively computes the total size of a file or directory.
    public static func size(of url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return Int64(size ?? 0)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    /// The total size in bytes across the given items.
    public static func totalSize(of items: [AppRelatedItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }
}