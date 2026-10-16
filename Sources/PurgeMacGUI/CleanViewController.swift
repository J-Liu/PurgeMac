// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import PurgeMacCore

/// Junk-cleanup section: scans one category at a time, shows checkable items,
/// and moves the selected items (excluding large files) to the Trash.
final class CleanViewController: NSViewController {
    private let categoryTableView = NSTableView()
    private let itemTableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: L("clean.status.initial"))
    private let cleanButton = NSButton(title: L("clean.button.clean"), target: nil, action: nil)

    private let scanner = JunkScanner()
    private var itemsByCategory: [JunkCategory: [JunkItem]] = [:]
    private var scannedCategories: Set<JunkCategory> = []
    private var currentCategory: JunkCategory?
    private var selectedIndexes: Set<Int> = []

    override func loadView() {
        let root = NSView()

        categoryTableView.delegate = self
        categoryTableView.dataSource = self
        categoryTableView.allowsMultipleSelection = false
        categoryTableView.usesAlternatingRowBackgroundColors = true

        let categoryColumns: [(String, String, CGFloat)] = [
            ("name", L("clean.column.category"), 200),
            ("size", L("clean.column.size"), 140),
            ("action", L("clean.column.action"), 100),
        ]
        for (identifier, title, width) in categoryColumns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.resizingMask = (identifier == "name") ? .autoresizingMask : .userResizingMask
            categoryTableView.addTableColumn(column)
        }

        let categoryScroll = NSScrollView()
        categoryScroll.documentView = categoryTableView
        categoryScroll.hasVerticalScroller = true

        itemTableView.delegate = self
        itemTableView.dataSource = self
        itemTableView.usesAlternatingRowBackgroundColors = true
        let itemColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        itemColumn.title = L("clean.column.items")
        itemColumn.width = 560
        itemColumn.resizingMask = .autoresizingMask
        itemTableView.addTableColumn(itemColumn)

        let itemScroll = NSScrollView()
        itemScroll.documentView = itemTableView
        itemScroll.hasVerticalScroller = true

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        cleanButton.target = self
        cleanButton.action = #selector(cleanClicked)
        cleanButton.bezelStyle = .rounded
        cleanButton.isEnabled = false

        for subview in [categoryScroll, itemScroll, statusLabel, cleanButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            categoryScroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            categoryScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            categoryScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            categoryScroll.heightAnchor.constraint(equalToConstant: 200),

            itemScroll.topAnchor.constraint(equalTo: categoryScroll.bottomAnchor, constant: 12),
            itemScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            itemScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            itemScroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            cleanButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            cleanButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            cleanButton.widthAnchor.constraint(equalToConstant: 96),
            cleanButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 12),
        ])

        view = root
    }

    // MARK: - Scanning

    @objc private func scanCategoryClicked(_ sender: NSButton) {
        let categories = JunkCategory.allCases
        guard sender.tag >= 0, sender.tag < categories.count else { return }
        let category = categories[sender.tag]

        statusLabel.stringValue = L("clean.status.scanning", category.localizedDisplayName)
        let scanner = self.scanner

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = scanner.scan(category: category)
            DispatchQueue.main.async {
                self?.itemsByCategory[category] = items
                self?.scannedCategories.insert(category)
                self?.currentCategory = category
                self?.selectedIndexes = []
                self?.categoryTableView.reloadData()
                self?.refreshItems(for: category)
                self?.statusLabel.stringValue = category == .largeFiles
                    ? L("clean.status.largeFiles", items.count)
                    : L("clean.status.found", items.count, category.localizedDisplayName)
            }
        }
    }

    private func refreshItems(for category: JunkCategory) {
        let items = itemsByCategory[category] ?? []
        itemTableView.reloadData()
        cleanButton.isEnabled = !items.isEmpty && category != .largeFiles
    }

    // MARK: - Clean

    @objc private func cleanClicked() {
        guard let category = currentCategory, category != .largeFiles else { return }
        let items = itemsByCategory[category] ?? []
        let itemsToClean = items.enumerated()
            .filter { selectedIndexes.contains($0.offset) }
            .map(\.element)

        guard !itemsToClean.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L("clean.alert.noSelection.title")
            alert.informativeText = L("clean.alert.noSelection.message")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L("uninstall.alert.ok"))
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = L("clean.alert.confirm.title", itemsToClean.count)
        alert.informativeText = L("clean.alert.confirm.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("clean.alert.confirm.clean"))
        alert.addButton(withTitle: L("uninstall.alert.confirm.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let itemsCopy = itemsToClean
        let scanner = self.scanner

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = JunkCleaner().clean(itemsCopy)
            let refreshed = scanner.scan(category: category)
            DispatchQueue.main.async {
                self?.selectedIndexes = []
                self?.itemsByCategory[category] = refreshed
                self?.refreshItems(for: category)
                self?.categoryTableView.reloadData()
                self?.statusLabel.stringValue = L("clean.status.freed", Self.formatBytes(result.freedBytes))
            }
        }
    }

    @objc private func deleteLargeFileClicked(_ sender: NSButton) {
        guard let category = currentCategory else { return }
        let items = itemsByCategory[category] ?? []
        guard sender.tag >= 0, sender.tag < items.count else { return }
        let item = items[sender.tag]

        let alert = NSAlert()
        alert.messageText = L("clean.alert.move.title")
        alert.informativeText = item.path
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("clean.button.moveToTrash"))
        alert.addButton(withTitle: L("uninstall.alert.confirm.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let scanner = self.scanner
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = JunkCleaner().clean([item])
            let refreshed = scanner.scan(category: category)
            DispatchQueue.main.async {
                self?.itemsByCategory[category] = refreshed
                self?.refreshItems(for: category)
                self?.categoryTableView.reloadData()
                self?.statusLabel.stringValue = L("clean.status.freed", Self.formatBytes(result.freedBytes))
            }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Table data source and delegate

extension CleanViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === categoryTableView {
            return JunkCategory.allCases.count
        }
        guard let category = currentCategory else { return 0 }
        return itemsByCategory[category]?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === categoryTableView {
            return categoryCellView(for: tableColumn, row: row)
        }
        return itemCellView(row: row)
    }

    private func categoryCellView(for tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let category = JunkCategory.allCases[row]
        let identifier = tableColumn.identifier

        if identifier.rawValue == "action" {
            let button = NSButton(title: L("clean.button.scan"), target: self, action: #selector(scanCategoryClicked))
            button.bezelStyle = .rounded
            button.tag = row
            return button
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

        if identifier.rawValue == "name" {
            textField.stringValue = category.localizedDisplayName
        } else {
            if scannedCategories.contains(category) {
                let total = JunkScanner.totalSize(of: itemsByCategory[category] ?? [])
                textField.stringValue = Self.formatBytes(total)
            } else {
                textField.stringValue = L("junk.notScanned")
            }
        }
        return cell
    }

    private func itemCellView(row: Int) -> NSView? {
        guard let category = currentCategory,
              let items = itemsByCategory[category],
              row < items.count else {
            return nil
        }
        let item = items[row]

        if category == .largeFiles {
            let container = NSView()
            let label = NSTextField(labelWithString: "\(item.path) — \(Self.formatBytes(item.size))")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingMiddle

            let deleteButton = NSButton(title: L("clean.button.moveToTrash"), target: self, action: #selector(deleteLargeFileClicked))
            deleteButton.bezelStyle = .rounded
            deleteButton.tag = row
            deleteButton.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(label)
            container.addSubview(deleteButton)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -12),

                deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(itemCheckboxToggled(_:)))
        checkbox.title = "[\(category.rawValue)] \(item.path) — \(Self.formatBytes(item.size))"
        checkbox.tag = row
        checkbox.state = selectedIndexes.contains(row) ? .on : .off
        return checkbox
    }

    @objc private func itemCheckboxToggled(_ sender: NSButton) {
        if sender.state == .on {
            selectedIndexes.insert(sender.tag)
        } else {
            selectedIndexes.remove(sender.tag)
        }
    }
}
