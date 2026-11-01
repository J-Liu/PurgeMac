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

    // MARK: - Cache scanning (System Junk)

    /// Scans user caches directory and determines safe defaults.
    /// Strategy from purge-app's CacheScanner:
    /// - Scan ~/Library/Caches for app caches
    /// - Check safety policy for each item
    /// - Most third-party caches are safe to clean
    private func scanCaches() -> [JunkItem] {
        var items: [JunkItem] = []
        let cachesURL = libraryPath("Caches")
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(
            at: cachesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }

        for entry in entries {
            let name = entry.lastPathComponent

            // Skip Apple system caches that may be important
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

            let isAppleSystemCache = appleSystemCaches.contains { name.hasPrefix($0) }

            let attributes = Self.attributes(for: entry)
            guard attributes.size > 0 else { continue }

            items.append(
                JunkItem(
                    path: entry.path,
                    size: attributes.size,
                    category: .userCaches,
                    lastAccessDate: attributes.lastAccessDate,
                    selectedByDefault: !isAppleSystemCache
                )
            )
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Log scanning (Logs and Error Reports)

    /// Scans log files and crash reports.
    /// Strategy from purge-app:
    /// - Application Logs: ~/Library/Logs (excluding DiagnosticReports)
    /// - Crash Reports: ~/Library/Logs/DiagnosticReports
    /// - Font Cache: ~/Library/Caches/com.apple.ATS
    private func scanLogs() -> [JunkItem] {
        var items: [JunkItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        // Application Logs - each subfolder as separate item (excluding DiagnosticReports)
        let logsDir = home.appendingPathComponent("Library/Logs", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                // Skip DiagnosticReports - handled separately
                if entry.lastPathComponent == "DiagnosticReports" { continue }

                let attributes = Self.attributes(for: entry)
                guard attributes.size > 0 else { continue }

                items.append(
                    JunkItem(
                        path: entry.path,
                        size: attributes.size,
                        category: .logs,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: true
                    )
                )
            }
        }

        // Crash Reports
        let crashReportsDir = home.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        if fm.fileExists(atPath: crashReportsDir.path) {
            let attributes = Self.attributes(for: crashReportsDir)
            if attributes.size > 0 {
                items.append(
                    JunkItem(
                        path: crashReportsDir.path,
                        size: attributes.size,
                        category: .logs,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: true
                    )
                )
            }
        }

        // Font Cache
        let fontCacheDir = home.appendingPathComponent("Library/Caches/com.apple.ATS", isDirectory: true)
        if fm.fileExists(atPath: fontCacheDir.path) {
            let attributes = Self.attributes(for: fontCacheDir)
            if attributes.size > 0 {
                items.append(
                    JunkItem(
                        path: fontCacheDir.path,
                        size: attributes.size,
                        category: .logs,
                        lastAccessDate: attributes.lastAccessDate,
                        selectedByDefault: true
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Leftovers scanning (Orphan files from uninstalled apps)

    /// Minimum days before a leftover is considered stale enough to offer.
    private static let minimumStaleDays = 30

    /// Minimum number of installed apps for a complete view.
    private static let minimumPlausibleAppCount = 5

    /// Scans for orphaned files from uninstalled applications.
    /// Uses purge-app's OrphanLeftoverScanPolicy strategy:
    /// - Only offer items whose owner is confirmed gone
    /// - Items must be untouched for minimumStaleDays
    /// - Never offer Apple system items
    /// - Items are NOT selected by default
    private func scanLeftovers() -> [JunkItem] {
        var items: [JunkItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Build index of installed apps
        let installedIndex = Self.makeInstalledAppIndex()
        guard installedIndex.looksComplete else { return [] }

        // Staleness cutoff
        let cutoff = Date().addingTimeInterval(-Double(Self.minimumStaleDays) * 24 * 60 * 60)

        // Orphan roots to scan (from purge-app's OrphanLeftoverScanPolicy.orphanRoots)
        let orphanRoots: [URL] = [
            home.appendingPathComponent("Library/Application Support", isDirectory: true),
            home.appendingPathComponent("Library/Containers", isDirectory: true),
            home.appendingPathComponent("Library/Group Containers", isDirectory: true),
            home.appendingPathComponent("Library/HTTPStorages", isDirectory: true),
            home.appendingPathComponent("Library/Saved Application State", isDirectory: true),
        ]

        var seen = Set<String>()

        for root in orphanRoots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let name = entry.lastPathComponent
                let lowerName = name.lowercased()

                // Skip Apple identifiers
                if lowerName.hasPrefix("com.apple.") || lowerName.contains(".com.apple.") {
                    continue
                }

                // Extract owner from entry name
                guard let owner = Self.candidateOwner(entryName: name, url: entry) else { continue }

                // Check if orphaned (no installed app owns it)
                guard Self.isOrphan(owner: owner, installed: installedIndex) else { continue }

                // Check staleness - must be untouched since cutoff
                guard case .untouchedSince(let lastModified) = Self.contentAge(of: entry, cutoff: cutoff) else {
                    continue
                }

                // Avoid duplicates
                let key = entry.standardizedFileURL.path
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                let size = Self.size(of: entry)
                guard size > 0 else { continue }

                items.append(
                    JunkItem(
                        path: entry.path,
                        size: size,
                        category: .leftovers,
                        lastAccessDate: lastModified,
                        selectedByDefault: false // Never pre-select orphan data
                    )
                )
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Installed App Index

    /// Index of installed apps used to determine if a leftover is orphaned.
    private struct InstalledAppIndex {
        var diskBundleIDs: Set<String>
        var diskAppNames: Set<String>
        var rootsReadable: Bool

        var appCount: Int { diskBundleIDs.count }
        var looksComplete: Bool { rootsReadable && appCount >= minimumPlausibleAppCount }

        /// Whether an installed app owns this bundle id (exact or as parent).
        func owns(bundleID: String) -> Bool {
            let lower = bundleID.lowercased()
            var components = lower.split(separator: ".").map(String.init)
            while components.count >= 2 {
                let candidate = components.joined(separator: ".")
                if diskBundleIDs.contains(candidate) { return true }
                components.removeLast()
            }
            return false
        }

        /// Whether an installed app owns this app group identifier.
        func owns(appGroup identifier: String, teamID: String) -> Bool {
            // If we can't verify, keep it (avoid false positives)
            let name = String(identifier.dropFirst(teamID.count + 1))
            if JunkScanner.looksLikeBundleID(name) && owns(bundleID: name) {
                return true
            }
            return false
        }
    }

    /// Builds an index of installed apps.
    private static func makeInstalledAppIndex() -> InstalledAppIndex {
        let fm = FileManager.default
        var ids = Set<String>()
        var names = Set<String>()
        var rootsReadable = true

        let appRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        for root in appRoots {
            guard fm.fileExists(atPath: root.path) else { continue }
            guard let bundles = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                rootsReadable = false
                continue
            }

            for bundleURL in bundles where bundleURL.pathExtension == "app" {
                if let bundle = Bundle(url: bundleURL) {
                    if let id = bundle.bundleIdentifier, !id.isEmpty {
                        ids.insert(id.lowercased())
                    }
                    if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
                        names.insert(name.lowercased())
                    }
                    if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
                        names.insert(name.lowercased())
                    }
                }
                // Also add the app name from the bundle filename
                let appName = bundleURL.deletingPathExtension().lastPathComponent.lowercased()
                names.insert(appName)
            }
        }

        return InstalledAppIndex(
            diskBundleIDs: ids,
            diskAppNames: names,
            rootsReadable: rootsReadable
        )
    }

    // MARK: - Owner extraction

    /// What a leftover's name says about its owner.
    private enum LeftoverOwner: Equatable {
        case bundleID(String)
        case appGroup(String, teamID: String)
    }

    /// Extracts the owner from an entry name.
    private static func candidateOwner(entryName name: String, url: URL) -> LeftoverOwner? {
        // Check if it looks like a bundle ID
        guard looksLikeBundleID(name) else {
            // Check for UUID container with metadata
            if name.count == 36 && name.contains("-") {
                return containerMetadataOwner(at: url)
            }
            return nil
        }

        // Direct bundle ID
        return .bundleID(name)
    }

    /// Reads container metadata to find the owning bundle ID.
    private static func containerMetadataOwner(at url: URL) -> LeftoverOwner? {
        let plistURL = url.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = object as? [String: Any] else { return nil }

        // Try nested structure first
        if let info = dict["MCMMetadataInfo"] as? [String: Any],
           let identifier = info["MCMMetadataIdentifier"] as? String,
           !identifier.isEmpty {
            return .bundleID(identifier)
        }

        // Try flat structure
        if let identifier = dict["MCMMetadataIdentifier"] as? String, !identifier.isEmpty {
            return .bundleID(identifier)
        }

        return nil
    }

    /// Whether a string looks like a reverse-DNS bundle identifier.
    private static func looksLikeBundleID(_ value: String) -> Bool {
        guard UUID(uuidString: value) == nil else { return false }
        guard !value.contains(where: \.isWhitespace) else { return false }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        guard segments.allSatisfy({ !$0.isEmpty }) else { return false }
        guard let first = value.first, first.isLetter else { return false }
        return true
    }

    /// Whether an owner is orphaned (no installed app claims it).
    private static func isOrphan(owner: LeftoverOwner, installed: InstalledAppIndex) -> Bool {
        switch owner {
        case .bundleID(let id):
            return !installed.owns(bundleID: id)
        case .appGroup(let identifier, let teamID):
            return !installed.owns(appGroup: identifier, teamID: teamID)
        }
    }

    // MARK: - Content age

    /// When anything inside a leftover was last changed.
    private enum ContentAge {
        case recent
        case untouchedSince(Date)
        case unknown
    }

    /// Files whose date says nothing about use.
    private static let contentAgeIgnoredNames: Set<String> = [
        ".DS_Store",
        ".com.apple.containermanagerd.metadata.plist"
    ]

    /// How much later a folder's date may be than an ignored file.
    private static let ignoredFileDateTolerance: TimeInterval = 2

    /// Checks if content has been untouched since cutoff.
    private static func contentAge(of url: URL, cutoff: Date) -> ContentAge {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey]
        var checkURL = url
        checkURL.removeAllCachedResourceValues()

        guard let top = try? checkURL.resourceValues(forKeys: keys),
              let topDate = top.contentModificationDate,
              topDate > .distantPast else { return .unknown }

        guard top.isDirectory == true, top.isSymbolicLink != true else {
            return topDate >= cutoff ? .recent : .untouchedSince(topDate)
        }

        // Walk directory to check all files
        var unexplainedFolders: [String: Date] = [:]
        var newest = Date.distantPast

        if topDate >= cutoff {
            unexplainedFolders[url.standardizedFileURL.resolvingSymlinksInPath().path] = topDate
        } else {
            newest = topDate
        }

        var failed = false
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in failed = true; return false }
        ) else { return .unknown }

        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: keys) else { return .unknown }
            if values.isSymbolicLink == true { continue }

            guard let date = values.contentModificationDate, date > .distantPast else { return .unknown }

            if contentAgeIgnoredNames.contains(item.lastPathComponent) {
                let parent = item.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().path
                if let folderDate = unexplainedFolders[parent],
                   folderDate <= date.addingTimeInterval(ignoredFileDateTolerance) {
                    unexplainedFolders[parent] = nil
                }
                continue
            }

            if values.isDirectory == true {
                if date >= cutoff {
                    unexplainedFolders[item.standardizedFileURL.resolvingSymlinksInPath().path] = date
                } else if date > newest {
                    newest = date
                }
                continue
            }

            if date >= cutoff { return .recent }
            if date > newest { newest = date }
        }

        if failed { return .unknown }
        if !unexplainedFolders.isEmpty { return .recent }
        guard newest > .distantPast else { return .unknown }
        return .untouchedSince(newest)
    }

    /// Recursively computes the total size of a file or directory.
    private static func size(of url: URL) -> Int64 {
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