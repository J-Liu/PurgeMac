// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// String normalization extensions for matching
extension String {
    /// Normalizes string for matching by removing common separators and lowercasing
    func normalizedForMatching() -> String {
        self.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    /// Strips trailing version numbers (e.g., "App 2.1.0" -> "App")
    func strippingTrailingVersion() -> String {
        self.replacingOccurrences(
            of: #"\s+\d+(\.\d+)*\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    /// Returns only letters, lowercased
    var lettersOnly: String {
        self.filter { $0.isLetter }.lowercased()
    }

    /// Extracts company name from bundle ID (com.company.app -> company)
    var bundleCompanyName: String? {
        let components = self.components(separatedBy: ".")
        guard components.count >= 3 else { return nil }
        let company = components[1]
        return company.isEmpty ? nil : company.normalizedForMatching()
    }

    /// Returns last two components of bundle ID (company.app)
    var bundleLastTwoComponents: String {
        let components = self.components(separatedBy: ".")
            .compactMap { $0 != "-" ? $0.lowercased() : nil }
        return components.suffix(2).joined()
    }

    /// Extracts base bundle ID by removing common suffixes
    var baseBundleIdentifier: String? {
        let components = self.components(separatedBy: ".")
        let suffixes: Set<String> = [
            "helper", "agent", "daemon", "service", "xpc",
            "launcher", "updater", "installer", "uninstaller",
            "login", "extension", "plugin"
        ]
        guard components.count >= 4,
              let last = components.last?.lowercased(),
              suffixes.contains(last) else { return nil }
        return components.dropLast().joined(separator: ".")
    }
}

/// Locations where app files may exist
struct ScanLocations {
    static let standardLibrarySubdirectories: Set<String> = [
        "Application Scripts", "Application Support", "Caches",
        "Containers", "Group Containers", "HTTPStorages",
        "Internet Plug-Ins", "LaunchAgents", "LaunchDaemons",
        "Logs", "Preferences", "PreferencePanes",
        "PrivilegedHelperTools", "Saved Application State",
        "Services", "WebKit", "Extensions", "Frameworks"
    ]

    static var home: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Core locations to scan for app leftovers
    static var paths: [String] {
        let (cacheDir, tempDir) = darwinCT()

        var paths: [String] = [
            // User home - scoped subdirs (bare $HOME intentionally NOT scanned)
            "\(home)/.config",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Applications",
            // User Library
            "\(home)/Library",
            "\(home)/Library/Application Scripts",
            "\(home)/Library/Application Support",
            "\(home)/Library/Application Support/CrashReporter",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments",
            "\(home)/Library/Containers",
            "\(home)/Library/Caches",
            "\(home)/Library/Caches/com.apple.helpd/Generated",
            "\(home)/Library/Caches/com.crashlytics",
            "\(home)/Library/Caches/com.google.SoftwareUpdate",
            "\(home)/Library/Caches/com.google.Keystone",
            "\(home)/Library/Caches/org.sparkle-project.Sparkle",
            "\(home)/Library/Caches/com.segment.analytics",
            "\(home)/Library/Caches/SentryCrash",
            "\(home)/Library/Caches/Rollbar",
            "\(home)/Library/Caches/Amplitude",
            "\(home)/Library/Caches/Realm",
            "\(home)/Library/Caches/Parse",
            "\(home)/Library/Group Containers",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Internet Plug-Ins",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Logs/DiagnosticReports",
            "\(home)/Library/Preferences",
            "\(home)/Library/PreferencePanes",
            "\(home)/Library/Preferences/ByHost",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/Services",
            "\(home)/Library/WebKit",
            // System-wide
            "/Applications",
            "/Users/Shared",
            "/Users/Shared/Library/Application Support",
            "/Library",
            "/Library/Application Support",
            "/Library/Application Support/CrashReporter",
            "/Library/Caches",
            "/Library/Extensions",
            "/Library/Internet Plug-Ins",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/Library/Logs",
            "/Library/Logs/DiagnosticReports",
            "/Library/Preferences",
            "/Library/PrivilegedHelperTools",
            "/private/var/db/receipts",
            "/private/tmp",
            "/usr/local/bin",
            "/usr/local/etc",
            "/usr/local/opt",
            "/usr/local/sbin",
            "/usr/local/share",
            "/usr/local/var",
            cacheDir,
            tempDir
        ]

        // Dynamically append Application Support subfolders for deeper search
        let subfolders = listAppSupportDirectories()
        for folder in subfolders {
            paths.append("\(home)/Library/Application Support/\(folder)")
        }

        return paths
    }

    static func darwinCT() -> (String, String) {
        var cacheDir = ""
        var tempDir = ""
        if let cfCacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            cacheDir = cfCacheDir
        }
        if let cfTempDir = ProcessInfo.processInfo.environment["TMPDIR"] {
            tempDir = cfTempDir
        }
        return (cacheDir, tempDir)
    }

    static func listAppSupportDirectories() -> [String] {
        let appSupportPath = "\(home)/Library/Application Support"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appSupportPath) else {
            return []
        }
        return contents.filter { item in
            var isDir: ObjCBool = false
            let fullPath = (appSupportPath as NSString).appendingPathComponent(item)
            return FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
        }
    }

    /// Directories to skip during deep search
    static let skipDeepSearch: Set<String> = [
        "Apple", "Audio", "Bluetooth", "ColorSync", "Components",
        "CoreAnalytics", "Developer", "Java", "Perl", "Python", "Ruby",
        "SystemExtensions", "Security", "Sandbox", "Spotlight",
        "Keychains", "Fonts", "ColorPickers", "Sounds", "Speech",
        "Screen Savers", "Printers", "Documentation"
    ]
}

/// Discovers files and folders left behind after an application is removed.
/// Uses multi-level heuristic matching similar to PureMac.
public struct LeftoverScanner {

    public init() {}

    /// Scans for leftovers belonging to the given app
    public func scan(bundleID: String, appName: String) -> [LeftoverItem] {
        var results: Set<URL> = []

        // Pre-compute normalized identifiers
        let normalizedBundleID = bundleID.normalizedForMatching()
        let bundleLastTwo = bundleID.bundleLastTwoComponents
        let normalizedAppName = appName.normalizedForMatching()
        let appNameLetters = appName.lettersOnly
        let pathComponentName = appName.replacingOccurrences(of: ".app", with: "")
            .normalizedForMatching()
        let companyName = bundleID.bundleCompanyName
        let baseBundleID = bundleID.baseBundleIdentifier?.normalizedForMatching()
        let strippedAppName = appName.strippingTrailingVersion().normalizedForMatching()

        // Scan each location
        for location in ScanLocations.paths {
            let isLibRoot = location.hasSuffix("/Library") || location == "/Library"
            let maxDepth = isLibRoot ? 2 : 1
            scanLocation(
                location,
                currentDepth: 0,
                maxDepth: maxDepth,
                isLibraryRoot: isLibRoot,
                normalizedBundleID: normalizedBundleID,
                bundleLastTwo: bundleLastTwo,
                normalizedAppName: normalizedAppName,
                appNameLetters: appNameLetters,
                pathComponentName: pathComponentName,
                companyName: companyName,
                baseBundleID: baseBundleID,
                strippedAppName: strippedAppName,
                results: &results
            )
        }

        // Discover containers
        let containers = discoverContainers(bundleID: bundleID, normalizedBundleID: normalizedBundleID)
        results.formUnion(containers)

        // Convert to LeftoverItems with sizes
        var items: [LeftoverItem] = results.map { url in
            let size = Self.size(of: url)
            let category = Self.categorize(url: url)
            return LeftoverItem(path: url.path, size: size, category: category)
        }

        // Sort by size (largest first)
        items.sort { $0.size > $1.size }

        return items
    }

    private func scanLocation(
        _ location: String,
        currentDepth: Int,
        maxDepth: Int,
        isLibraryRoot: Bool,
        normalizedBundleID: String,
        bundleLastTwo: String,
        normalizedAppName: String,
        appNameLetters: String,
        pathComponentName: String,
        companyName: String?,
        baseBundleID: String?,
        strippedAppName: String?,
        results: inout Set<URL>
    ) {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: location) else {
            return
        }

        var subdirs: [URL] = []

        for item in contents {
            let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)

            // Determine normalized name
            let normalizedName: String
            if itemURL.hasDirectoryPath || itemURL.pathExtension.isEmpty {
                normalizedName = item.normalizedForMatching()
            } else {
                normalizedName = (item as NSString).deletingPathExtension.normalizedForMatching()
            }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { continue }

            // Skip if already in results
            if results.contains(itemURL) { continue }

            // Check if matches
            if matchesApp(
                normalizedName: normalizedName,
                normalizedBundleID: normalizedBundleID,
                bundleLastTwo: bundleLastTwo,
                normalizedAppName: normalizedAppName,
                appNameLetters: appNameLetters,
                pathComponentName: pathComponentName,
                companyName: companyName,
                baseBundleID: baseBundleID,
                strippedAppName: strippedAppName
            ) {
                results.insert(itemURL)
            }

            // Recurse into subdirectories
            if isDir.boolValue && currentDepth < maxDepth {
                if isLibraryRoot && currentDepth == 0 {
                    if !ScanLocations.skipDeepSearch.contains(itemURL.lastPathComponent) {
                        subdirs.append(itemURL)
                    }
                } else {
                    subdirs.append(itemURL)
                }
            }
        }

        // Recurse
        for subdir in subdirs {
            scanLocation(
                subdir.path,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                isLibraryRoot: isLibraryRoot,
                normalizedBundleID: normalizedBundleID,
                bundleLastTwo: bundleLastTwo,
                normalizedAppName: normalizedAppName,
                appNameLetters: appNameLetters,
                pathComponentName: pathComponentName,
                companyName: companyName,
                baseBundleID: baseBundleID,
                strippedAppName: strippedAppName,
                results: &results
            )
        }
    }

    private func matchesApp(
        normalizedName: String,
        normalizedBundleID: String,
        bundleLastTwo: String,
        normalizedAppName: String,
        appNameLetters: String,
        pathComponentName: String,
        companyName: String?,
        baseBundleID: String?,
        strippedAppName: String?
    ) -> Bool {
        let minLen = 5

        // Level 1: Full bundle ID
        if normalizedBundleID.count >= 5 && normalizedName.contains(normalizedBundleID) {
            return true
        }

        // Level 2: App name
        if normalizedAppName.count >= minLen && normalizedName.contains(normalizedAppName) {
            return true
        }

        // Level 3: Path component name
        if pathComponentName.count >= minLen && normalizedName.contains(pathComponentName) {
            return true
        }

        // Level 4: Letters-only app name
        if appNameLetters.count >= minLen && normalizedName.contains(appNameLetters) {
            return true
        }

        // Level 5: Last two bundle components
        if bundleLastTwo.count >= minLen && normalizedName.contains(bundleLastTwo) {
            return true
        }

        // Level 6: Base bundle ID (strips helper/agent/daemon suffixes)
        if let base = baseBundleID, base.count >= minLen && normalizedName.contains(base) {
            return true
        }

        // Level 7: Version-stripped app name
        if let stripped = strippedAppName, stripped.count >= minLen &&
            stripped != normalizedAppName && normalizedName.contains(stripped) {
            return true
        }

        // Level 8: Company name from bundle ID
        if let company = companyName, company.count >= minLen && normalizedName.contains(company) {
            return true
        }

        return false
    }

    /// Discovers sandboxed app containers
    private func discoverContainers(bundleID: String, normalizedBundleID: String) -> [URL] {
        var containers: [URL] = []

        guard let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Containers") else { return containers }

        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: containersPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return containers }

        for dir in dirs {
            let dirName = dir.lastPathComponent

            // UUID-named containers: read metadata plist
            if dirName.count == 36 && dirName.contains("-") {
                let metaPlist = dir.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                if let meta = NSDictionary(contentsOf: metaPlist),
                   let containerBundleID = meta["MCMMetadataIdentifier"] as? String,
                   containerBundleID == bundleID {
                    containers.append(dir)
                }
            }

            // Named containers matching bundle ID directly
            if normalizedBundleID.count >= 5,
               dirName.normalizedForMatching() == normalizedBundleID {
                containers.append(dir)
            }
        }

        return containers
    }

    /// Categorizes a URL into a LeftoverCategory
    private static func categorize(url: URL) -> LeftoverCategory {
        let path = url.path.lowercased()
        if path.contains("/caches/") { return .caches }
        if path.contains("/logs/") { return .logs }
        if path.contains("/preferences/") { return .preferences }
        if path.contains("/containers/") { return .containers }
        if path.contains("/application support/") { return .applicationSupport }
        if path.contains("/saved application state/") { return .savedApplicationState }
        return .other
    }

    /// The total size in bytes across the given leftovers.
    public static func totalSize(of items: [LeftoverItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
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
