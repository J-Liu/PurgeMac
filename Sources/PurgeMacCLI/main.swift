// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import PurgeMacCore

private func printUsage() {
    print("PurgeMac CLI")
    print("Usage:")
    print("  PurgeMacCLI list-apps [--json]")
    print("    List user-installed applications.")
    print("  PurgeMacCLI uninstall <bundle-id> [--dry-run]")
    print("    Move an installed application to the Trash.")
    print("  PurgeMacCLI scan-leftovers <bundle-id>")
    print("    Scan Library directories for leftovers of an app.")
    print("  PurgeMacCLI clean-leftovers <bundle-id> [--dry-run]")
    print("    Move an app's leftovers to the Trash.")
    print("  PurgeMacCLI scan-junk --category=<category>")
    print("    Scan junk items for a category.")
    print("  PurgeMacCLI clean-junk --category=<category> [--confirm] [--dry-run]")
    print("    Move junk items to the Trash.")
}

private func runListApps(arguments: [String]) {
    let apps = AppScanner().scan()

    if arguments.contains("--json") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(apps),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
        return
    }

    guard !apps.isEmpty else {
        print("No user-installed applications found.")
        return
    }

    let header = ["Name", "Bundle ID", "Version", "Path"]
    var rows: [[String]] = [header]
    for app in apps {
        rows.append([app.name, app.bundleID, app.version, app.path])
    }

    let widths = columnWidths(for: rows)
    for row in rows {
        let line = zip(row, widths)
            .map { $0.padding(toLength: $1, withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
        print(line)
    }
}

/// Computes the maximum display width for each column so the table aligns.
private func columnWidths(for rows: [[String]]) -> [Int] {
    guard let columnCount = rows.map(\.count).max() else { return [] }
    var widths = Array(repeating: 0, count: columnCount)
    for row in rows {
        for (index, value) in row.enumerated() {
            widths[index] = max(widths[index], value.count)
        }
    }
    return widths
}

private func runUninstall(arguments: [String]) {
    let dryRun = arguments.contains("--dry-run")
    let bundleID = arguments.first { !$0.hasPrefix("--") }

    guard let bundleID, !bundleID.isEmpty else {
        print("Usage: PurgeMacCLI uninstall <bundle-id> [--dry-run]")
        exit(1)
    }

    guard let app = AppScanner().scan().first(where: { $0.bundleID == bundleID }) else {
        print("Application not found: \(bundleID)")
        exit(1)
    }

    if dryRun {
        print("Would uninstall: \(app.name) (\(app.bundleID))")
        print("Path: \(app.path)")
        return
    }

    print("The following application will be moved to the Trash:")
    print("  Name:      \(app.name)")
    print("  Bundle ID: \(app.bundleID)")
    print("  Version:   \(app.version)")
    print("  Path:      \(app.path)")
    print("Type 'yes' to confirm:")

    guard let answer = readLine(), answer == "yes" else {
        print("Aborted.")
        exit(0)
    }

    do {
        try Uninstaller().uninstallApp(app)
        print("Moved to Trash: \(app.name)")
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

/// Formats a byte count into a human-readable string.
private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func runScanLeftovers(arguments: [String]) {
    let bundleID = arguments.first { !$0.hasPrefix("--") }

    guard let bundleID, !bundleID.isEmpty else {
        print("Usage: PurgeMacCLI scan-leftovers <bundle-id>")
        exit(1)
    }

    guard let app = AppScanner().scan().first(where: { $0.bundleID == bundleID }) else {
        print("Application not found: \(bundleID)")
        exit(1)
    }

    let items = LeftoverScanner().scan(bundleID: app.bundleID, appName: app.name)

    guard !items.isEmpty else {
        print("No leftovers found for \(app.name).")
        return
    }

    printLeftoverTable(items)
    print("Total: \(formatBytes(LeftoverScanner.totalSize(of: items)))")
}

/// Prints a leftover scan result as an aligned table.
private func printLeftoverTable(_ items: [LeftoverItem]) {
    let header = ["Category", "Size", "Path"]
    var rows: [[String]] = [header]
    for item in items {
        rows.append([item.category.rawValue, formatBytes(item.size), item.path])
    }

    let widths = columnWidths(for: rows)
    for row in rows {
        let line = zip(row, widths)
            .map { $0.padding(toLength: $1, withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
        print(line)
    }
}

private func runCleanLeftovers(arguments: [String]) {
    let dryRun = arguments.contains("--dry-run")
    let bundleID = arguments.first { !$0.hasPrefix("--") }

    guard let bundleID, !bundleID.isEmpty else {
        print("Usage: PurgeMacCLI clean-leftovers <bundle-id> [--dry-run]")
        exit(1)
    }

    guard let app = AppScanner().scan().first(where: { $0.bundleID == bundleID }) else {
        print("Application not found: \(bundleID)")
        exit(1)
    }

    let items = LeftoverScanner().scan(bundleID: app.bundleID, appName: app.name)

    guard !items.isEmpty else {
        print("No leftovers found for \(app.name).")
        return
    }

    printLeftoverTable(items)
    let total = LeftoverScanner.totalSize(of: items)

    if dryRun {
        print("Would clean \(items.count) item(s), freeing \(formatBytes(total)).")
        return
    }

    print("Total: \(formatBytes(total))")
    print("Type 'yes' to confirm:")

    guard let answer = readLine(), answer == "yes" else {
        print("Aborted.")
        exit(0)
    }

    let result = LeftoverCleaner().clean(items)
    for item in result.succeeded {
        print("Moved to Trash: \(item.path)")
    }
    for failure in result.failures {
        print("Failed: \(failure.path) — \(failure.reason)")
    }
    print("Freed \(formatBytes(result.freedBytes)).")
}

/// Extracts the value of a `--category=<value>` argument, if present.
private func categoryArgument(from arguments: [String]) -> String? {
    for arg in arguments where arg.hasPrefix("--category=") {
        return String(arg.dropFirst("--category=".count))
    }
    return nil
}

/// Formats a date for CLI output, or returns a placeholder when unknown.
private func formatDate(_ date: Date?) -> String {
    guard let date else { return "-" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

/// Resolves the categories requested by `--category=<value>`.
///
/// The special value `all` expands to every supported category.
private func resolveCategories(from arguments: [String]) -> [JunkCategory] {
    guard let name = categoryArgument(from: arguments), !name.isEmpty else {
        print("Missing --category=<category>.")
        exit(1)
    }
    if name == "all" {
        return JunkCategory.allCases
    }
    guard let category = JunkCategory(rawValue: name) else {
        print("Unknown category: \(name)")
        let supported = JunkCategory.allCases.map(\.rawValue).joined(separator: ", ")
        print("Supported categories: \(supported), all")
        exit(1)
    }
    return [category]
}

private func printJunkTable(_ items: [JunkItem]) {
    let header = ["Category", "Size", "Last Accessed", "Path"]
    var rows: [[String]] = [header]
    for item in items {
        rows.append([item.category.displayName, formatBytes(item.size), formatDate(item.lastAccessDate), item.path])
    }
    let widths = columnWidths(for: rows)
    for row in rows {
        let line = zip(row, widths)
            .map { $0.padding(toLength: $1, withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
        print(line)
    }
}

private func runScanJunk(arguments: [String]) {
    let categories = resolveCategories(from: arguments)
    let scanner = JunkScanner()
    var foundAny = false

    for category in categories {
        let items = scanner.scan(category: category)
        guard !items.isEmpty else { continue }
        foundAny = true

        print("[\(category.displayName)]")
        printJunkTable(items)
        print("Subtotal: \(formatBytes(JunkScanner.totalSize(of: items)))")
        print("")
    }

    if !foundAny {
        print("No junk found.")
    }
}

private func runCleanJunk(arguments: [String]) {
    let categories = resolveCategories(from: arguments)
    let dryRun = arguments.contains("--dry-run")
    let confirm = arguments.contains("--confirm")
    let scanner = JunkScanner()

    // Large files are shown for awareness but never auto-removed.
    var cleanableItems: [JunkItem] = []
    var listOnlyItems: [JunkItem] = []

    for category in categories {
        let items = scanner.scan(category: category)
        if category == .largeFiles {
            listOnlyItems.append(contentsOf: items)
        } else {
            cleanableItems.append(contentsOf: items)
        }
    }

    if !cleanableItems.isEmpty {
        printJunkTable(cleanableItems)
    }
    if !listOnlyItems.isEmpty {
        print("[\(JunkCategory.largeFiles.displayName) — list only, not removed]")
        printJunkTable(listOnlyItems)
    }

    let total = JunkScanner.totalSize(of: cleanableItems)
    guard !cleanableItems.isEmpty else {
        print("No cleanable junk found.")
        return
    }

    if dryRun {
        print("Would clean \(cleanableItems.count) item(s), freeing \(formatBytes(total)).")
        return
    }

    print("Total: \(formatBytes(total))")
    if !confirm {
        print("Type 'yes' to confirm:")
        guard let answer = readLine(), answer == "yes" else {
            print("Aborted.")
            exit(0)
        }
    }

    let result = JunkCleaner().clean(cleanableItems)
    for item in result.succeeded {
        print("Moved to Trash: \(item.path)")
    }
    for failure in result.failures {
        print("Failed: \(failure.path) — \(failure.reason)")
    }
    print("Freed \(formatBytes(result.freedBytes)).")
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    print("PurgeMac CLI v\(PurgeMacVersion.string)")
    printUsage()
    exit(0)
}

switch command {
case "list-apps":
    runListApps(arguments: Array(arguments.dropFirst()))
case "uninstall":
    runUninstall(arguments: Array(arguments.dropFirst()))
case "scan-leftovers":
    runScanLeftovers(arguments: Array(arguments.dropFirst()))
case "clean-leftovers":
    runCleanLeftovers(arguments: Array(arguments.dropFirst()))
case "scan-junk":
    runScanJunk(arguments: Array(arguments.dropFirst()))
case "clean-junk":
    runCleanJunk(arguments: Array(arguments.dropFirst()))
default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
