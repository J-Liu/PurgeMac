// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import PurgeMacCore

/// App-uninstall section: lists installed apps, shows leftovers for the
/// selected app, and moves the app (plus chosen leftovers) to the Trash.
final class UninstallViewController: NSViewController {
    private let searchField = NSSearchField()
    private let appTableView = NSTableView()
    private let leftoverTableView = NSTableView()
    private let detailLabel = NSTextField(labelWithString: L("uninstall.select.prompt"))
    private let statusLabel = NSTextField(labelWithString: "")
    private let uninstallButton = NSButton(title: L("uninstall.button.uninstall"), target: nil, action: nil)

    private var apps: [InstalledApp] = []
    private var filteredApps: [InstalledApp] = []
    private var selectedApp: InstalledApp?
    private var leftovers: [LeftoverItem] = []
    private var selectedLeftoverIndexes: Set<Int> = []

    override func loadView() {
        let root = NSView()

        appTableView.delegate = self
        appTableView.dataSource = self
        appTableView.allowsMultipleSelection = false
        appTableView.usesAlternatingRowBackgroundColors = true
        appTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let appColumns: [(String, String, CGFloat)] = [
            ("icon", L("uninstall.column.icon"), 40),
            ("name", L("uninstall.column.name"), 220),
            ("version", L("uninstall.column.version"), 90),
            ("bundleID", L("uninstall.column.bundleID"), 260),
        ]
        for (identifier, title, width) in appColumns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.resizingMask = (identifier == "bundleID") ? .autoresizingMask : .userResizingMask
            appTableView.addTableColumn(column)
        }

        let appScroll = NSScrollView()
        appScroll.documentView = appTableView
        appScroll.hasVerticalScroller = true
        appScroll.hasHorizontalScroller = true

        leftoverTableView.delegate = self
        leftoverTableView.dataSource = self
        leftoverTableView.usesAlternatingRowBackgroundColors = true
        let leftoverColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("leftover"))
        leftoverColumn.title = L("uninstall.leftover.title")
        leftoverColumn.width = 460
        leftoverColumn.resizingMask = .autoresizingMask
        leftoverTableView.addTableColumn(leftoverColumn)

        let leftoverScroll = NSScrollView()
        leftoverScroll.documentView = leftoverTableView
        leftoverScroll.hasVerticalScroller = true

        let detailPanel = NSView()
        detailPanel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.maximumNumberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallClicked)
        uninstallButton.bezelStyle = .rounded

        for subview in [detailLabel, leftoverScroll, statusLabel, uninstallButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            detailPanel.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            detailLabel.topAnchor.constraint(equalTo: detailPanel.topAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: detailPanel.trailingAnchor, constant: -12),

            leftoverScroll.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 8),
            leftoverScroll.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            leftoverScroll.trailingAnchor.constraint(equalTo: detailPanel.trailingAnchor, constant: -12),
            leftoverScroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            statusLabel.bottomAnchor.constraint(equalTo: detailPanel.bottomAnchor, constant: -12),

            uninstallButton.trailingAnchor.constraint(equalTo: detailPanel.trailingAnchor, constant: -12),
            uninstallButton.bottomAnchor.constraint(equalTo: detailPanel.bottomAnchor, constant: -12),
            uninstallButton.widthAnchor.constraint(equalToConstant: 96),
            uninstallButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 12),
        ])

        searchField.delegate = self
        searchField.placeholderString = L("uninstall.search.placeholder")

        for subview in [searchField, appScroll, detailPanel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 30),

            appScroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            appScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            appScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            appScroll.bottomAnchor.constraint(equalTo: detailPanel.topAnchor, constant: -12),

            detailPanel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            detailPanel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            detailPanel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            detailPanel.heightAnchor.constraint(equalToConstant: 260),
        ])

        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshApps()

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    @objc private func languageDidChange() {
        reloadData()
    }

    func reloadData() {
        // Update search placeholder
        searchField.placeholderString = L("uninstall.search.placeholder")
        // Update column titles
        if let iconColumn = appTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("icon")) {
            iconColumn.title = L("uninstall.column.icon")
        }
        if let nameColumn = appTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("name")) {
            nameColumn.title = L("uninstall.column.name")
        }
        if let versionColumn = appTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("version")) {
            versionColumn.title = L("uninstall.column.version")
        }
        if let bundleIDColumn = appTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("bundleID")) {
            bundleIDColumn.title = L("uninstall.column.bundleID")
        }
        if let leftoverColumn = leftoverTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("leftover")) {
            leftoverColumn.title = L("uninstall.leftover.title")
        }
        // Update button title
        uninstallButton.title = L("uninstall.button.uninstall")
        // Refresh detail label if no app selected
        if selectedApp == nil {
            detailLabel.stringValue = L("uninstall.select.prompt")
        }
        // Reload tables
        appTableView.reloadData()
        leftoverTableView.reloadData()
    }

    // MARK: - Data

    private func refreshApps() {
        apps = AppScanner().scan()
        filterApps()
    }

    private func filterApps() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredApps = apps
        } else {
            let lowerQuery = query.lowercased()
            filteredApps = apps.filter {
                $0.name.lowercased().contains(lowerQuery) || $0.bundleID.lowercased().contains(lowerQuery)
            }
        }
        appTableView.reloadData()
        if selectedApp == nil {
            clearSelection()
        }
    }

    private func selectApp(_ app: InstalledApp?) {
        selectedApp = app
        guard let app else {
            clearSelection()
            return
        }
        leftovers = LeftoverScanner().scan(bundleID: app.bundleID, appName: app.name)
        selectedLeftoverIndexes.removeAll()
        detailLabel.stringValue = "\(app.name) — v\(app.version)\n\(app.path)"
        statusLabel.stringValue = leftovers.isEmpty
            ? L("uninstall.leftover.none")
            : L("uninstall.leftover.count", leftovers.count)
        leftoverTableView.reloadData()
    }

    private func clearSelection() {
        selectedApp = nil
        leftovers = []
        selectedLeftoverIndexes.removeAll()
        detailLabel.stringValue = L("uninstall.select.prompt")
        statusLabel.stringValue = ""
        leftoverTableView.reloadData()
    }

    // MARK: - Actions

    @objc private func uninstallClicked() {
        guard let app = selectedApp else {
            let alert = NSAlert()
            alert.messageText = L("uninstall.alert.noApp.title")
            alert.informativeText = L("uninstall.alert.noApp.message")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L("uninstall.alert.ok"))
            alert.runModal()
            return
        }

        let leftoversToClean = leftovers.enumerated()
            .filter { selectedLeftoverIndexes.contains($0.offset) }
            .map(\.element)

        let alert = NSAlert()
        alert.messageText = L("uninstall.alert.confirm.title", app.name)
        var informative = L("uninstall.alert.confirm.message")
        if !leftoversToClean.isEmpty {
            informative = L("uninstall.alert.confirm.message.withLeftovers", leftoversToClean.count)
        }
        alert.informativeText = informative
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("uninstall.alert.confirm.uninstall"))
        alert.addButton(withTitle: L("uninstall.alert.confirm.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let appCopy = app
        let leftoversCopy = leftoversToClean

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try Uninstaller().uninstallApp(appCopy)
                let cleanResult = LeftoverCleaner().clean(leftoversCopy)

                DispatchQueue.main.async {
                    var message = L("uninstall.result.moved", appCopy.name)
                    message += "\n" + L("uninstall.result.freed", Self.formatBytes(cleanResult.freedBytes))
                    if !cleanResult.failures.isEmpty {
                        message += "\n" + L("uninstall.result.partial", cleanResult.failures.count)
                    }
                    self?.statusLabel.stringValue = message
                    self?.selectedApp = nil
                    self?.refreshApps()
                }
            } catch {
                DispatchQueue.main.async {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = L("uninstall.alert.failed.title")
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.alertStyle = .critical
                    errorAlert.addButton(withTitle: L("uninstall.alert.ok"))
                    errorAlert.runModal()
                }
            }
        }
    }

    @objc private func leftoverCheckboxToggled(_ sender: NSButton) {
        if sender.state == .on {
            selectedLeftoverIndexes.insert(sender.tag)
        } else {
            selectedLeftoverIndexes.remove(sender.tag)
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Table data source and delegate

extension UninstallViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === appTableView {
            return filteredApps.count
        }
        return leftovers.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === appTableView {
            return appCellView(for: tableColumn, row: row)
        }
        return leftoverCellView(row: row)
    }

    private func appCellView(for tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let app = filteredApps[row]
        let identifier = tableColumn.identifier

        if identifier.rawValue == "icon" {
            let cell = NSTableCellView()
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = NSWorkspace.shared.icon(forFile: app.path)
            cell.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 24),
                imageView.heightAnchor.constraint(equalToConstant: 24),
            ])
            return cell
        }

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        switch identifier.rawValue {
        case "name": textField.stringValue = app.name
        case "version": textField.stringValue = app.version
        case "bundleID": textField.stringValue = app.bundleID
        default: textField.stringValue = ""
        }
        return cell
    }

    private func leftoverCellView(row: Int) -> NSView? {
        guard row < leftovers.count else { return nil }
        let item = leftovers[row]
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(leftoverCheckboxToggled))
        checkbox.title = "[\(item.category.rawValue)] \(item.path) — \(Self.formatBytes(item.size))"
        checkbox.tag = row
        checkbox.state = selectedLeftoverIndexes.contains(row) ? .on : .off
        return checkbox
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView, tableView === appTableView else { return }
        let row = appTableView.selectedRow
        guard row >= 0, row < filteredApps.count else {
            selectApp(nil)
            return
        }
        selectApp(filteredApps[row])
    }
}

// MARK: - Search field

extension UninstallViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterApps()
    }
}
