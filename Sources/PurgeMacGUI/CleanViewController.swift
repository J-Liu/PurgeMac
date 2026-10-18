// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import PurgeMacCore

/// Junk-cleanup section: scans one category at a time, shows checkable items,
/// and moves the selected items to the Trash.
final class CleanViewController: NSViewController {
    private let itemTableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: L("clean.status.initial"))
    private let selectAllCheckbox = NSButton(checkboxWithTitle: L("clean.selectAll"), target: nil, action: nil)
    private let moveToTrashButton = NSButton(title: L("clean.button.moveToTrash"), target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()
    private let loadingOverlay = NSView()

    private let scanner = JunkScanner()
    private var itemsByCategory: [JunkCategory: [JunkItem]] = [:]
    private var currentCategory: JunkCategory?
    private var selectedIndexes: Set<Int> = []
    private var currentMode: String = "cleanup"
    private var isLoading = false

    func setMode(_ identifier: String) {
        currentMode = identifier
        currentCategory = nil
        selectedIndexes = []
        itemTableView.reloadData()
        updateMoveToTrashButtonVisibility()

        switch identifier {
        case "clean.caches":
            autoScanCategory(.userCaches)
        case "clean.logs":
            autoScanCategory(.logs)
        case "clean.leftovers":
            statusLabel.stringValue = "App Leftovers - Coming Soon"
        case "clean.largeFiles":
            autoScanCategory(.largeFiles)
        default:
            break
        }
    }

    private func autoScanCategory(_ category: JunkCategory) {
        isLoading = true
        loadingOverlay.isHidden = false
        progressIndicator.startAnimation(nil)
        itemTableView.reloadData()
        selectAllCheckbox.isHidden = true
        moveToTrashButton.isHidden = true
        statusLabel.stringValue = L("clean.status.scanning", category.localizedDisplayName)

        let scanner = self.scanner

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = scanner.scan(category: category)
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.progressIndicator.stopAnimation(nil)
                self?.loadingOverlay.isHidden = true
                self?.itemsByCategory[category] = items
                self?.currentCategory = category
                self?.selectedIndexes = []
                self?.itemTableView.reloadData()
                self?.updateSelectAllCheckboxState()
                self?.updateMoveToTrashButtonVisibility()
                self?.selectAllCheckbox.isHidden = items.isEmpty
                self?.statusLabel.stringValue = category == .largeFiles
                    ? L("clean.status.largeFiles", items.count)
                    : L("clean.status.found", items.count, category.localizedDisplayName)
            }
        }
    }

    func reloadData() {
        if let itemColumn = itemTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("item")) {
            itemColumn.title = L("clean.column.items")
        }
        setMoveToTrashButtonTitle()
        selectAllCheckbox.title = L("clean.selectAll")
        if currentCategory == nil && !isLoading {
            statusLabel.stringValue = L("clean.status.initial")
        }
        itemTableView.reloadData()
    }

    override func loadView() {
        let root = NSView()

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

        // Loading overlay with semi-transparent background
        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.7).cgColor
        loadingOverlay.isHidden = true
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(progressIndicator)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        selectAllCheckbox.target = self
        selectAllCheckbox.action = #selector(selectAllToggled)
        selectAllCheckbox.translatesAutoresizingMaskIntoConstraints = false
        selectAllCheckbox.isHidden = true

        setMoveToTrashButtonTitle()
        moveToTrashButton.target = self
        moveToTrashButton.action = #selector(moveToTrashClicked)
        moveToTrashButton.bezelStyle = .rounded
        moveToTrashButton.isHidden = true
        moveToTrashButton.translatesAutoresizingMaskIntoConstraints = false

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )

        for subview in [statusLabel, selectAllCheckbox, moveToTrashButton, itemScroll, loadingOverlay] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            selectAllCheckbox.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            selectAllCheckbox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),

            moveToTrashButton.centerYAnchor.constraint(equalTo: selectAllCheckbox.centerYAnchor),
            moveToTrashButton.leadingAnchor.constraint(equalTo: selectAllCheckbox.trailingAnchor, constant: 12),
            moveToTrashButton.widthAnchor.constraint(equalToConstant: 110),

            itemScroll.topAnchor.constraint(equalTo: selectAllCheckbox.bottomAnchor, constant: 8),
            itemScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            itemScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            itemScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            loadingOverlay.topAnchor.constraint(equalTo: itemScroll.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: itemScroll.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: itemScroll.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: itemScroll.bottomAnchor),

            progressIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
        ])

        view = root
    }

    @objc private func languageDidChange() {
        reloadData()
    }

    private func setMoveToTrashButtonTitle() {
        let title = L("clean.button.moveToTrash")
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemRed
        ]
        moveToTrashButton.attributedTitle = NSAttributedString(string: title, attributes: attrs)
    }

    @objc private func selectAllToggled(_ sender: NSButton) {
        guard let category = currentCategory else { return }
        let items = itemsByCategory[category] ?? []
        if sender.state == .on {
            selectedIndexes = Set(0..<items.count)
        } else {
            selectedIndexes.removeAll()
        }
        itemTableView.reloadData()
        updateMoveToTrashButtonVisibility()
    }

    private func updateSelectAllCheckboxState() {
        guard let category = currentCategory else {
            selectAllCheckbox.state = .off
            selectAllCheckbox.isEnabled = false
            return
        }
        let items = itemsByCategory[category] ?? []
        if items.isEmpty {
            selectAllCheckbox.state = .off
            selectAllCheckbox.isEnabled = false
        } else if selectedIndexes.count == items.count {
            selectAllCheckbox.state = .on
            selectAllCheckbox.isEnabled = true
        } else if selectedIndexes.isEmpty {
            selectAllCheckbox.state = .off
            selectAllCheckbox.isEnabled = true
        } else {
            selectAllCheckbox.state = .mixed
            selectAllCheckbox.isEnabled = true
        }
    }

    private func updateMoveToTrashButtonVisibility() {
        moveToTrashButton.isHidden = selectedIndexes.isEmpty
    }

    @objc private func itemCheckboxToggled(_ sender: NSButton) {
        if sender.state == .on {
            selectedIndexes.insert(sender.tag)
        } else {
            selectedIndexes.remove(sender.tag)
        }
        updateSelectAllCheckboxState()
        updateMoveToTrashButtonVisibility()
    }

    @objc private func moveToTrashClicked() {
        guard let category = currentCategory else { return }
        let items = itemsByCategory[category] ?? []
        let itemsToClean = items.enumerated()
            .filter { selectedIndexes.contains($0.offset) }
            .map(\.element)

        guard !itemsToClean.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = L("clean.alert.confirm.title", itemsToClean.count)
        alert.informativeText = L("clean.alert.confirm.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("clean.alert.confirm.clean"))
        alert.addButton(withTitle: L("uninstall.alert.confirm.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let itemsCopy = itemsToClean
        let scanner = self.scanner
        let categoryCopy = category

        isLoading = true
        loadingOverlay.isHidden = false
        progressIndicator.startAnimation(nil)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = JunkCleaner().clean(itemsCopy)
            let refreshed = scanner.scan(category: categoryCopy)
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.progressIndicator.stopAnimation(nil)
                self?.loadingOverlay.isHidden = true
                self?.selectedIndexes = []
                self?.itemsByCategory[categoryCopy] = refreshed
                self?.itemTableView.reloadData()
                self?.updateSelectAllCheckboxState()
                self?.updateMoveToTrashButtonVisibility()
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
        guard let category = currentCategory else { return 0 }
        return itemsByCategory[category]?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let category = currentCategory,
              let items = itemsByCategory[category],
              row < items.count else {
            return nil
        }
        let item = items[row]

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(itemCheckboxToggled(_:)))
        checkbox.title = "\(item.path) — \(Self.formatBytes(item.size))"
        checkbox.tag = row
        checkbox.state = selectedIndexes.contains(row) ? .on : .off
        return checkbox
    }
}