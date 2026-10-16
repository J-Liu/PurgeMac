// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Discovers files and folders left behind after an application is removed.
///
/// The scanner only looks at the top level of each standard Library directory and
/// matches entries whose names reference the app's bundle identifier or name.
public struct LeftoverScanner {
    public init() {}

    /// Scans the user Library for leftovers belonging to the given app.
    public func scan(bundleID: String, appName: String) -> [LeftoverItem] {
        var items: [LeftoverItem] = []
        let fileManager = FileManager.default

        for category in LeftoverCategory.allCases {
            let directory = category.directoryURL
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries where Self.nameMatches(
                entry.lastPathComponent,
                bundleID: bundleID,
                appName: appName
            ) {
                let size = Self.size(of: entry)
                items.append(LeftoverItem(path: entry.path, size: size, category: category))
            }
        }

        // Larger items first so the most impactful leftovers are prominent.
        return items.sorted { $0.size > $1.size }
    }

    /// The total size in bytes across the given leftovers.
    public static func totalSize(of items: [LeftoverItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    /// Decides whether an entry name references the app.
    ///
    /// Matching is deliberately conservative to avoid removing unrelated data:
    /// - the name contains the bundle identifier, or
    /// - the name equals the app name, or
    /// - the name starts with the app name followed by a separator character.
    private static func nameMatches(_ name: String, bundleID: String, appName: String) -> Bool {
        let lowerName = name.lowercased()

        let lowerBundleID = bundleID.lowercased()
        if !lowerBundleID.isEmpty && lowerName.contains(lowerBundleID) {
            return true
        }

        let lowerAppName = appName.lowercased()
        guard !lowerAppName.isEmpty else { return false }

        if lowerName == lowerAppName {
            return true
        }

        // Separator check catches patterns like "AppName Helper" or "AppName.plist".
        if let range = lowerName.range(of: lowerAppName), range.lowerBound == lowerName.startIndex {
            let endIndex = range.upperBound
            if endIndex < lowerName.endIndex {
                let nextChar = lowerName[endIndex]
                if " .-_".contains(nextChar) {
                    return true
                }
            }
        }

        return false
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
}
