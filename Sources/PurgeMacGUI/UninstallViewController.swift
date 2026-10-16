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
    private let selectAllCheckbox = NSButton(checkboxWithTitle: L("uninstall.selectAll"), target: nil, action: nil)
    private let appProgressIndicator = NSProgressIndicator()
    private let leftoverProgressIndicator = NSProgressIndicator()

    private var apps: [InstalledApp] = []
    private var filteredApps: [InstalledApp] = []
    private var selectedApp: InstalledApp?
    private var leftovers: [LeftoverItem] = []
    private var selectedLeftoverIndexes: Set<Int> = []
    private var isLoadingApps = false
    private var isLoadingLeftovers = false

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

        // App loading progress indicator
        appProgressIndicator.style = .spinning
        appProgressIndicator.controlSize = .small
        appProgressIndicator.translatesAutoresizingMaskIntoConstraints = false

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

        // Leftover loading progress indicator
        leftoverProgressIndicator.style = .spinning
        leftoverProgressIndicator.controlSize = .small
        leftoverProgressIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Select All checkbox for leftovers
        selectAllCheckbox.target = self
        selectAllCheckbox.action = #selector(selectAllLeftoversToggled)
        selectAllCheckbox.translatesAutoresizingMaskIntoConstraints = false
        selectAllCheckbox.isHidden = true

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
        uninstallButton.isHidden = true

        for subview in [detailLabel, selectAllCheckbox, leftoverProgressIndicator, leftoverScroll, statusLabel, uninstallButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            detailPanel.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            detailLabel.topAnchor.constraint(equalTo: detailPanel.topAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: detailPanel.trailingAnchor, constant: -12),

            selectAllCheckbox.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 8),
            selectAllCheckbox.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),

            leftoverProgressIndicator.centerXAnchor.constraint(equalTo: leftoverScroll.centerXAnchor),
            leftoverProgressIndicator.centerYAnchor.constraint(equalTo: leftoverScroll.centerYAnchor),

            leftoverScroll.topAnchor.constraint(equalTo: selectAllCheckbox.bottomAnchor, constant: 4),
            leftoverScroll.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            leftoverScroll.trailingAnchor.constraint(equalTo: detailPanel.trailingAnchor, constant: -12),
            leftoverScroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            statusLabel.bottomAnchor.constraint(equalTo: detailPanel.bottomAnchor, constant: -12),

            uninstallButton.leadingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: 12),
            uninstallButton.bottomAnchor.constraint(equalTo: detailPanel.bottomAnchor, constant: -12),
            uninstallButton.widthAnchor.constraint(equalToConstant: 96),
        ])

        searchField.delegate = self
        searchField.placeholderString = L("uninstall.search.placeholder")

        for subview in [searchField, appProgressIndicator, appScroll, detailPanel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 30),

            appProgressIndicator.centerXAnchor.constraint(equalTo: appScroll.centerXAnchor),
            appProgressIndicator.centerYAnchor.constraint(equalTo: appScroll.centerYAnchor),

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
        refreshAppsAsync()

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
        selectAllCheckbox.title = L("uninstall.selectAll")
        // Refresh detail label if no app selected
        if selectedApp == nil && !isLoadingLeftovers {
            detailLabel.stringValue = L("uninstall.select.prompt")
        }
        // Reload tables
        appTableView.reloadData()
        leftoverTableView.reloadData()
    }

    // MARK: - Async Data Loading

    private func refreshAppsAsync() {
        isLoadingApps = true
        appProgressIndicator.startAnimation(nil)
        appTableView.isHidden = true
        apps = []
        filteredApps = []
        appTableView.reloadData()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scannedApps = AppScanner().scan()
            DispatchQueue.main.async {
                self?.isLoadingApps = false
                self?.appProgressIndicator.stopAnimation(nil)
                self?.appTableView.isHidden = false
                self?.apps = scannedApps
                self?.filterApps()
            }
        }
    }

    private func selectAppAsync(_ app: InstalledApp?) {
        selectedApp = app
        guard let app else {
            clearSelection()
            return
        }

        // Show loading state
        isLoadingLeftovers = true
        leftoverProgressIndicator.startAnimation(nil)
        leftoverTableView.isHidden = true
        selectAllCheckbox.isHidden = true
        uninstallButton.isHidden = true
        detailLabel.stringValue = "\(app.name) — v\(app.version)\n\(app.path)"
        statusLabel.stringValue = L("uninstall.scanning.leftovers")
        leftovers = []
        selectedLeftoverIndexes.removeAll()
        leftoverTableView.reloadData()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scannedLeftovers = LeftoverScanner().scan(bundleID: app.bundleID, appName: app.name)
            DispatchQueue.main.async {
                guard let self = self, self.selectedApp?.bundleID == app.bundleID else { return }
                self.isLoadingLeftovers = false
                self.leftoverProgressIndicator.stopAnimation(nil)
                self.leftoverTableView.isHidden = false
                self.leftovers = scannedLeftovers
                self.statusLabel.stringValue = scannedLeftovers.isEmpty
                    ? L("uninstall.leftover.none")
                    : L("uninstall.leftover.count", scannedLeftovers.count)
                self.selectAllCheckbox.isHidden = scannedLeftovers.isEmpty
                self.updateSelectAllCheckboxState()
                self.updateUninstallButtonVisibility()
                self.leftoverTableView.reloadData()
            }
        }
    }

    // MARK: - Data

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

    private func clearSelection() {
        selectedApp = nil
        leftovers = []
        selectedLeftoverIndexes.removeAll()
        detailLabel.stringValue = L("uninstall.select.prompt")
        statusLabel.stringValue = ""
        selectAllCheckbox.isHidden = true
        uninstallButton.isHidden = true
        leftoverTableView.reloadData()
        updateSelectAllCheckboxState()
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
                    self?.refreshAppsAsync()
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
        updateSelectAllCheckboxState()
        updateUninstallButtonVisibility()
    }

    @objc private func selectAllLeftoversToggled(_ sender: NSButton) {
        if sender.state == .on {
            for i in 0..<leftovers.count {
                selectedLeftoverIndexes.insert(i)
            }
        } else {
            selectedLeftoverIndexes.removeAll()
        }
        leftoverTableView.reloadData()
        updateUninstallButtonVisibility()
    }

    private func updateSelectAllCheckboxState() {
        if leftovers.isEmpty {
            selectAllCheckbox.state = .off
            selectAllCheckbox.isEnabled = false
        } else if selectedLeftoverIndexes.count == leftovers.count {
            selectAllCheckbox.state = .on
            selectAllCheckbox.isEnabled = true
        } else if selectedLeftoverIndexes.isEmpty {
            selectAllCheckbox.state = .off
            selectAllCheckbox.isEnabled = true
        } else {
            selectAllCheckbox.state = .mixed
            selectAllCheckbox.isEnabled = true
        }
    }

    private func updateUninstallButtonVisibility() {
        // Show uninstall button only when an app is selected
        uninstallButton.isHidden = selectedApp == nil
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
            selectAppAsync(nil)
            return
        }
        selectAppAsync(filteredApps[row])
    }
}

// MARK: - Search field

extension UninstallViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterApps()
    }
}
