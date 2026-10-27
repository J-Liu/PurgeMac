// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Scans junk directories and returns items that are safe to clean up.
///
/// Categories differ in how they discover items:
/// - caches and logs scan the top level of their Library directories,
/// - browser and developer caches target a fixed set of known directories,
/// - large files recursively walk configured directories looking for big or old files,
/// - trash lists the current contents of the Trash.
public struct JunkScanner {
    /// The number of days an item must be untouched to be eligible for
    /// time-filtered categories.
    public let olderThanDays: Int

    /// Files larger than this many bytes are reported by the large-files scan.
    public let largeFileThreshold: Int64

    /// Files older than this many months (and >oldFileMinSize) are also reported.
    public let oldFileMonths: Int

    /// Minimum size in bytes for old files to be reported.
    public let oldFileMinSize: Int64

    /// Directories to scan for large files.
    public let scanDirs: [String]

    /// Directories to exclude from large file scan.
    public let excludedDirs: [String]

    public init(
        olderThanDays: Int = 30,
        largeFileThresholdMB: Int64? = nil,
        oldFileMonths: Int? = nil,
        oldFileMinSizeMB: Int64? = nil,
        scanDirs: [String]? = nil,
        excludedDirs: [String]? = nil
    ) {
        self.olderThanDays = olderThanDays

        // Read from UserDefaults or use defaults
        let defaults = UserDefaults.standard
        let thresholdMB = largeFileThresholdMB ?? Int64(defaults.object(forKey: "settings.largeFileThresholdMB") as? Int ?? 100)
        let months = oldFileMonths ?? defaults.object(forKey: "settings.oldFileMonths") as? Int ?? 12
        let minSizeMB = oldFileMinSizeMB ?? Int64(defaults.object(forKey: "settings.oldFileMinSizeMB") as? Int ?? 10)

        self.largeFileThreshold = max(1, thresholdMB) * 1024 * 1024
        self.oldFileMonths = months
        self.oldFileMinSize = max(1, minSizeMB) * 1024 * 1024

        // Expand ~ in paths
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expandPath: (String) -> String = { path in
            path.replacingOccurrences(of: "~", with: home)
        }

        if let dirs = scanDirs {
            self.scanDirs = dirs.map(expandPath)
        } else {
            let rawDirs = defaults.stringArray(forKey: "settings.largeFileScanDirs") ?? ["~/Downloads", "~/Documents", "~/Desktop"]
            self.scanDirs = rawDirs.map(expandPath)
        }

        if let dirs = excludedDirs {
            self.excludedDirs = dirs.map(expandPath)
        } else {
            let rawDirs = defaults.stringArray(forKey: "settings.largeFileExcludedDirs") ?? []
            self.excludedDirs = rawDirs.map(expandPath)
        }
    }

    /// Scans the given category and returns eligible junk, largest first.
    public func scan(category: JunkCategory) -> [JunkItem] {
        switch category {
        case .userCaches:
            return scanCaches()
        case .logs:
            return scanLogs()
        case .leftovers:
            return scanLeftovers()
        case .browserCaches:
            return scanItems(browserCacheDirectories(), category: category, timeFiltered: true)
        case .developerCaches:
            return scanItems(developerCacheDirectories(), category: category, timeFiltered: true)
        case .largeFiles:
            return scanLargeFiles()
        case .trash:
            return scanItems(trashContents(), category: category, timeFiltered: false)
        }
    }

    // MARK: - Leftovers scanning

    /// Scans for orphaned files from uninstalled applications.
    private func scanLeftovers() -> [JunkItem] {
        var items: [JunkItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Get installed app identifiers for filtering
        let knownAppIDs = Self.getInstalledAppIdentifiers()
        let knownAppNames = Self.getInstalledAppNames()

        // Paths to scan for orphaned files
        let searchPaths: [String] = [
            "\(home)/Library/Application Scripts",
            "\(home)/Library/Application Support",
            "\(home)/Library/Containers",
            "\(home)/Library/Caches",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Internet Plug-Ins",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Preferences",
            "\(home)/Library/PreferencePanes",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/WebKit",
            "/Library/Application Support",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]

        // Prefixes to skip (Apple system items, etc.)
        let skipPrefixes: Set<String> = [
            "apple", "com.apple", "comapple", "temporary", "system",
            "dock", "loginwindow", "launchd", "coresimulator",
            "mobilesync", "cloudkit", "icloud", "siri", "spotlight",
            "safari", "webkit", "mail", "messages", "facetime",
            "photos", "music", "podcasts", "news", "maps", "calendar",
            "contacts", "reminders", "notes", "keychainaccess",
            "bluetooth", "wifi", "network", "disk", "fsck",
            " installd", "configd", "cfprefsd", "distnoted",
        ]

        for searchPath in searchPaths {
            let url = URL(fileURLWithPath: searchPath)
            guard let entries = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let name = entry.lastPathComponent.lowercased()

                // Skip system items
                var shouldSkip = false
                for prefix in skipPrefixes {
                    if name.hasPrefix(prefix) {
                        shouldSkip = true
                        break
                    }
                }
                if shouldSkip { continue }

                // Check if this item belongs to any known app
                let normalized = name.replacingOccurrences(of: "-", with: "")
                                   .replacingOccurrences(of: "_", with: "")
                                   .replacingOccurrences(of: ".", with: "")

                let belongsToKnownApp = knownAppIDs.contains { normalized.contains($0.lowercased()) } ||
                                        knownAppNames.contains { normalized.contains($0.lowercased()) }

                if belongsToKnownApp { continue }

                // This is a potential orphan
                let attributes = Self.attributes(for: entry)
                guard attributes.size > 0 else { continue }

                items.append(
                    JunkItem(
                        path: entry.path,
                        size: attributes.size,
                        category: .leftovers,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: false // Orphans are not selected by default - user should review
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Gets bundle identifiers of installed applications.
    private static func getInstalledAppIdentifiers() -> Set<String> {
        var identifiers = Set<String>()
        let appPaths = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        for appPath in appPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appPath) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: appPath).appendingPathComponent(item)
                if let bundle = Bundle(url: appURL),
                   let bundleID = bundle.bundleIdentifier {
                    // Normalize for matching (remove dots, dashes, underscores)
                    let normalized = bundleID.replacingOccurrences(of: "-", with: "")
                                            .replacingOccurrences(of: "_", with: "")
                                            .replacingOccurrences(of: ".", with: "")
                                            identifiers.insert(normalized)
                }
            }
        }
        return identifiers
    }

    /// Gets names of installed applications.
    private static func getInstalledAppNames() -> Set<String> {
        var names = Set<String>()
        let appPaths = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        for appPath in appPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appPath) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appName = (item as NSString).deletingPathExtension.lowercased()
                let normalized = appName.replacingOccurrences(of: " ", with: "")
                                       .replacingOccurrences(of: "-", with: "")
                                       .replacingOccurrences(of: "_", with: "")
                names.insert(normalized)
            }
        }
        return names
    }

    // MARK: - Cache scanning

    /// Scans user caches directory and determines safe defaults.
    private func scanCaches() -> [JunkItem] {
        var items: [JunkItem] = []
        let cachesURL = libraryPath("Caches")

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: cachesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }

        for entry in entries {
            let attributes = Self.attributes(for: entry)
            guard attributes.size > 0 else { continue }

            // Determine if safe to select by default
            let name = entry.lastPathComponent
            let selectedByDefault = shouldSelectCacheByDefault(name: name)

            items.append(
                JunkItem(
                    path: entry.path,
                    size: attributes.size,
                    category: .userCaches,
                    lastAccessDate: attributes.lastAccessDate,
                    selectedByDefault: selectedByDefault
                )
            )
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Determines if a cache directory should be selected by default.
    private func shouldSelectCacheByDefault(name: String) -> Bool {
        // Apple system caches that may be important
        let appleSystemCaches = [
            "com.apple.bird",
            "com.apple.CloudPhotosConfiguration",
            "com.apple.ContextStoreAgent",
            "com.apple.Messages",
            "com.apple.PhotoBooth",
            "com.apple.Safari",
            "com.apple.WebKit",
            "com.apple.coremediaassetsd",
            "com.apple.dt.Xcode",
            "com.apple.icloud",
            "com.apple.imessage",
            "com.apple.passd",
        ]

        // Check if it's an Apple system cache that might be important
        for prefix in appleSystemCaches {
            if name.hasPrefix(prefix) {
                return false
            }
        }

        // Most third-party caches are safe
        return true
    }

    // MARK: - Log scanning

    /// Scans logs and junk items based on PureMac's junk category.
    private func scanLogs() -> [JunkItem] {
        var items: [JunkItem] = []

        // Define targets similar to PureMac's junk category
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let h: (String) -> String = { "\(home)/\($0)" }

        struct LogTarget {
            let name: String
            let path: String
            let scanContents: Bool
            let selectedByDefault: Bool
        }

        let targets: [LogTarget] = [
            // User logs - scan contents
            LogTarget(name: "User Logs", path: h("Library/Logs"), scanContents: true, selectedByDefault: true),
            // Saved application state - not selected by default
            LogTarget(name: "Saved Application State", path: h("Library/Saved Application State"), scanContents: true, selectedByDefault: false),
            // Xcode items
            LogTarget(name: "Xcode DerivedData", path: h("Library/Developer/Xcode/DerivedData"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "Xcode Archives", path: h("Library/Developer/Xcode/Archives"), scanContents: false, selectedByDefault: false),
            LogTarget(name: "iOS DeviceSupport", path: h("Library/Developer/Xcode/iOS DeviceSupport"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "watchOS DeviceSupport", path: h("Library/Developer/Xcode/watchOS DeviceSupport"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "tvOS DeviceSupport", path: h("Library/Developer/Xcode/tvOS DeviceSupport"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "CoreSimulator Caches", path: h("Library/Developer/CoreSimulator/Caches"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "Xcode App Cache", path: h("Library/Caches/com.apple.dt.Xcode"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "XCTestDevices", path: h("Library/Developer/XCTestDevices"), scanContents: false, selectedByDefault: true),
            LogTarget(name: "SwiftUI Previews", path: h("Library/Developer/Xcode/UserData/Previews"), scanContents: false, selectedByDefault: true),
        ]

        for target in targets {
            if target.scanContents {
                // Scan children of the directory
                let dirURL = URL(fileURLWithPath: target.path)
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for entry in entries {
                    let attributes = Self.attributes(for: entry)
                    guard attributes.size > 0 else { continue }

                    items.append(
                        JunkItem(
                            path: entry.path,
                            size: attributes.size,
                            category: .logs,
                            lastAccessDate: attributes.lastAccessDate,
                            selectedByDefault: target.selectedByDefault
                        )
                    )
                }
            } else {
                // Treat the path itself as a single item
                let url = URL(fileURLWithPath: target.path)
                let attributes = Self.attributes(for: url)
                guard attributes.size > 0 else { continue }

                items.append(
                    JunkItem(
                        path: target.path,
                        size: attributes.size,
                        category: .logs,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: target.selectedByDefault
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    /// The total size in bytes across the given junk items.
    public static func totalSize(of items: [JunkItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    // MARK: - Category scans

    /// Treats each provided URL as a single junk item.
    private func scanItems(
        _ urls: [URL],
        category: JunkCategory,
        timeFiltered: Bool,
        selectedByDefault: Bool = true
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        let cutoff = cutoffDate()

        for url in urls {
            let attributes = Self.attributes(for: url)
            guard attributes.size > 0 else { continue }
            if timeFiltered {
                guard let lastAccessDate = attributes.lastAccessDate, lastAccessDate < cutoff else {
                    continue
                }
            }
            items.append(makeItem(from: url, attributes: attributes, category: category, selectedByDefault: selectedByDefault))
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Recursively finds individual files above the configured size threshold,
    /// or files older than oldFileMonths that are larger than oldFileMinSize.
    private func scanLargeFiles() -> [JunkItem] {
        var items: [JunkItem] = []
        let roots = scanDirs.map { URL(fileURLWithPath: $0) }

        let oldCutoff = Calendar.current.date(
            byAdding: .month,
            value: -max(1, oldFileMonths),
            to: Date()
        ) ?? Date.distantPast

        func isExcluded(_ path: String) -> Bool {
            for excluded in excludedDirs {
                if path == excluded || path.hasPrefix(excluded + "/") {
                    return true
                }
            }
            return false
        }

        for root in roots {
            guard !isExcluded(root.path),
                  let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                // Skip excluded directories
                if !excludedDirs.isEmpty && isExcluded(url.path) {
                    enumerator.skipDescendants()
                    continue
                }

                guard let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
                ),
                values.isRegularFile == true else { continue }

                let size = Int64(values.fileSize ?? 0)
                let modDate = values.contentModificationDate

                // Include if: size >= threshold OR (old enough AND >= oldFileMinSize)
                let isLarge = size >= largeFileThreshold
                let isOldAndBig = modDate != nil && modDate! < oldCutoff && size >= oldFileMinSize

                guard isLarge || isOldAndBig else { continue }

                items.append(
                    JunkItem(
                        path: url.path,
                        size: size,
                        category: .largeFiles,
                        lastAccessDate: modDate,
                        selectedByDefault: false
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    private func cutoffDate() -> Date {
        Date().addingTimeInterval(-TimeInterval(olderThanDays) * 86_400)
    }

    private func makeItem(from url: URL, attributes: (size: Int64, lastAccessDate: Date?), category: JunkCategory, selectedByDefault: Bool = true) -> JunkItem {
        JunkItem(
            path: url.path,
            size: attributes.size,
            category: category,
            lastAccessDate: attributes.lastAccessDate,
            selectedByDefault: selectedByDefault
        )
    }

    // MARK: - Known directories

    private func libraryPath(_ component: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent(component, isDirectory: true)
    }

    private func browserCacheDirectories() -> [URL] {
        [
            libraryPath("Caches/com.apple.Safari"),
            libraryPath("Caches/Google/Chrome"),
            libraryPath("Caches/Firefox"),
        ]
    }

    private func developerCacheDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            libraryPath("Developer/Xcode/DerivedData"),
            home.appendingPathComponent(".npm", isDirectory: true),
            libraryPath("Caches/Yarn"),
        ]
    }

    private func trashContents() -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries
    }

    // MARK: - Attribute helpers

    /// Reads the size and last-access date of a file or directory.
    private static func attributes(for url: URL) -> (size: Int64, lastAccessDate: Date?) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return (0, nil)
        }

        let values = try? url.resourceValues(
            forKeys: [.contentAccessDateKey, .contentModificationDateKey, .fileSizeKey]
        )
        let lastAccessDate = values?.contentAccessDate ?? values?.contentModificationDate

        if !isDirectory.boolValue {
            return (Int64(values?.fileSize ?? 0), lastAccessDate)
        }

        let size = Self.directorySize(at: url)
        return (size, lastAccessDate)
    }

    /// Recursively sums the size of regular files inside a directory.
    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
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
