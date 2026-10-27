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
        case .largeFiles:
            return scanLargeFiles()
        case .trash:
            return scanItems(trashContents(), category: category, timeFiltered: false)
        // Developer tools
        case .devXcode:
            return scanDevXcode()
        case .devHomebrew:
            return scanDevHomebrew()
        case .devNode:
            return scanDevNode()
        case .devPython:
            return scanDevPython()
        case .devRust:
            return scanDevRust()
        case .devGo:
            return scanDevGo()
        case .devJetBrains:
            return scanDevJetBrains()
        case .devVSCode:
            return scanDevVSCode()
        case .devContainers:
            return scanDevContainers()
        }
    }

    // MARK: - Leftovers scanning

    /// System prefixes that should never be flagged as orphans.
    private static let skipReverse: Set<String> = [
        // Apple & System
        "apple", "temporary", "btserver", "proapps", "scripteditor", "ilife",
        "livefsd", "siritoday", "addressbook", "animoji", "appstore",
        "askpermission", "callhistory", "clouddocs", "diskimages", "dock",
        "facetime", "fileprovider", "instruments", "knowledge", "mobilesync",
        "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy",
        "familycircle", "geoservices", "installation", "passkit",
        "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband",
        "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts",
        "ipod", "globalpreferences",
        // Analytics & Telemetry
        "apmanalytics", "apmexperiment", "avatarcache", "byhost",
        "contextstoreagent", "mobilemeaccounts", "mobiledocuments", "mobile",
        "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd",
        // Build Tools & Compilers
        "clang", "audiocomponent", "csexattrcryptoservice",
        "livetranscriptionagent", "sandboxhelper", "statuskitagent",
        // System Daemons
        "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed",
        "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd",
        "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd",
        "talagent", "watchlistd", "apptranslocation", "xcrun",
        // Generic Infrastructure
        "ds_store", "caches", "crashreporter", "trash",
        // Common SDKs and Shared Components
        "amsdatamigratortool", "arfilecache", "assistant", "chromium",
        "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit",
        "homebrew", "logi", "microsoft", "mozilla", "sync", "google",
        "sentinel", "hexnode", "sentry", "tvappservices", "reminders", "pbs",
        "notarytool", "differentialprivacy", "storeassetd", "webpush",
        "storedownloadd", "fsck", "crash", "python", "discrecording",
        "photossearch", "pylint", "jamf", "scopedbookmarkagent", "anonymous",
        "identifier", "isolated", "nobackup", "privacypreservingmeasurement",
        "symbols", "stickersd", "privatecloudcomputed", "tipsd",
        "controlcenter", "contactsd", "staticcheck", "index", "segment",
        "sparkle", "summaryevents", "launchdarkly", "identityservicesd",
        "embeddedbinaryvalidationutility", "aaprofilepicture", "minilauncher",
        "jna", "automator", "locationaccessstored", "spotlight", "cef"
    ]

    /// Blocked path fragments that should never appear in orphan results.
    private static let blockedFragments: [String] = [
        "/Library/Preferences",
        "/Library/PreferencePanes",
        "/Library/Containers",
        "/Library/Group Containers",
        "/Library/Application Scripts",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/Library/PrivilegedHelperTools",
        "/Library/Keychains",
        "/Library/Mail",
        "/Library/Safari",
        "/Library/Messages",
        "/Library/Calendars",
        "/Library/Accounts",
        "/Library/Mobile Documents",
        "/Library/CloudStorage",
    ]

    /// Scans for orphaned files from uninstalled applications.
    private func scanLeftovers() -> [JunkItem] {
        var items: [JunkItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Get installed app identifiers for filtering
        let knownAppIDs = Self.getInstalledAppIdentifiers()
        let knownAppNames = Self.getInstalledAppNames()

        // Only scan safe volatile data directories
        let searchPaths: [String] = [
            "\(home)/Library/Caches",
            "\(home)/Library/Logs",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/WebKit",
            "/Library/Caches",
            "/Library/Logs",
        ]

        for searchPath in searchPaths {
            let url = URL(fileURLWithPath: searchPath)
            guard let entries = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let name = entry.lastPathComponent
                let normalized = name.normalizedForMatching()

                // Skip known system items using skipReverse
                if Self.skipReverse.contains(where: { normalized.hasPrefix($0) }) { continue }

                // Skip Apple items
                if name.lowercased().hasPrefix("com.apple.") { continue }

                // Check if this item belongs to any known app
                let belongsToKnownApp = knownAppIDs.contains(where: { normalized.contains($0) }) ||
                                        knownAppNames.contains(where: { normalized.contains($0) })

                if belongsToKnownApp { continue }

                // Final safety check: ensure path doesn't contain blocked fragments
                let lowerPath = entry.path.lowercased()
                if Self.blockedFragments.contains(where: { lowerPath.contains($0.lowercased()) }) { continue }

                let attributes = Self.attributes(for: entry)
                guard attributes.size > 0 else { continue }

                items.append(
                    JunkItem(
                        path: entry.path,
                        size: attributes.size,
                        category: .leftovers,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: false
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

    // MARK: - Developer Tools Scanning

    /// Scans Xcode related caches and derived data.
    private func scanDevXcode() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Developer/Xcode/DerivedData", true),
            ("\(home)/Library/Developer/Xcode/Archives", false),
            ("\(home)/Library/Developer/Xcode/iOS DeviceSupport", true),
            ("\(home)/Library/Developer/Xcode/watchOS DeviceSupport", true),
            ("\(home)/Library/Developer/Xcode/tvOS DeviceSupport", true),
            ("\(home)/Library/Developer/CoreSimulator/Caches", true),
            ("\(home)/Library/Caches/com.apple.dt.Xcode", true),
            ("\(home)/Library/Developer/XCTestDevices", true),
            ("\(home)/Library/Developer/Xcode/UserData/Previews", true),
        ]
        return scanDevPaths(paths, category: .devXcode)
    }

    /// Scans Homebrew cache.
    private func scanDevHomebrew() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Caches/Homebrew", true),
        ]
        return scanDevPaths(paths, category: .devHomebrew)
    }

    /// Scans Node.js / npm / yarn / pnpm caches.
    private func scanDevNode() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/.npm/_cacache", true),
            ("\(home)/.npm/_logs", true),
            ("\(home)/Library/Caches/Yarn", true),
            ("\(home)/.cache/yarn", true),
            ("\(home)/.yarn/berry/cache", true),
            ("\(home)/Library/pnpm/store", true),
            ("\(home)/.pnpm-store", true),
            ("\(home)/.cache/pnpm", true),
        ]
        return scanDevPaths(paths, category: .devNode)
    }

    /// Scans Python / pip / Poetry caches.
    private func scanDevPython() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Caches/pip", true),
            ("\(home)/.cache/pip", true),
            ("\(home)/Library/Caches/pypoetry", true),
            ("\(home)/.cache/pypoetry", true),
        ]
        return scanDevPaths(paths, category: .devPython)
    }

    /// Scans Rust / Cargo caches.
    private func scanDevRust() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/.cargo/registry/cache", true),
            ("\(home)/.cargo/registry/index", true),
            ("\(home)/.cargo/git/db", true),
            ("\(home)/.cargo/git/checkouts", true),
        ]
        return scanDevPaths(paths, category: .devRust)
    }

    /// Scans Go caches.
    private func scanDevGo() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Caches/go-build", true),
            ("\(home)/go/pkg/mod/cache", true),
        ]
        return scanDevPaths(paths, category: .devGo)
    }

    /// Scans JetBrains IDEs caches.
    private func scanDevJetBrains() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Caches/JetBrains", true),
            ("\(home)/Library/Logs/JetBrains", true),
        ]
        return scanDevPaths(paths, category: .devJetBrains)
    }

    /// Scans VS Code caches.
    private func scanDevVSCode() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Application Support/Code/Cache", true),
            ("\(home)/Library/Application Support/Code/CachedData", true),
            ("\(home)/Library/Application Support/Code/CachedExtensionVSIXs", true),
            ("\(home)/Library/Application Support/Code/logs", true),
        ]
        return scanDevPaths(paths, category: .devVSCode)
    }

    /// Scans Docker / OrbStack caches.
    private func scanDevContainers() -> [JunkItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths: [(path: String, selected: Bool)] = [
            ("\(home)/Library/Containers/com.docker.docker/Data/cache", true),
            ("\(home)/Library/Containers/com.docker.docker/Data/log", true),
            ("\(home)/Library/Containers/com.docker.docker/Data/tmp", true),
            ("\(home)/Library/Group Containers/group.com.docker/Caches", true),
            ("\(home)/.orbstack/log", true),
            ("\(home)/Library/Caches/dev.kdrag0n.MacVirt", true),
            ("\(home)/Library/Logs/OrbStack", true),
        ]
        return scanDevPaths(paths, category: .devContainers)
    }

    /// Helper to scan developer tool paths.
    private func scanDevPaths(_ paths: [(path: String, selected: Bool)], category: JunkCategory) -> [JunkItem] {
        var items: [JunkItem] = []
        for (path, selected) in paths {
            let url = URL(fileURLWithPath: path)
            let attributes = Self.attributes(for: url)
            guard attributes.size > 0 else { continue }

            items.append(
                JunkItem(
                    path: path,
                    size: attributes.size,
                    category: category,
                    lastAccessDate: attributes.lastAccessDate,
                    selectedByDefault: selected
                )
            )
        }
        return items.sorted { $0.size > $1.size }
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

    /// Scans log files only.
    private func scanLogs() -> [JunkItem] {
        var items: [JunkItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Only scan actual log directories
        let logPaths: [(path: String, selectedByDefault: Bool)] = [
            ("\(home)/Library/Logs", true),
            ("\(home)/Library/Application Support/CrashReporter", true),
            ("/var/log", false), // System logs - not selected by default
        ]

        for (logPath, selected) in logPaths {
            let dirURL = URL(fileURLWithPath: logPath)
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
                        selectedByDefault: selected
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
