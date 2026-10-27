// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Represents a sidebar item, which may have children for expandable menus.
struct SidebarItem {
    let title: String
    let identifier: String
    let iconName: String
    var isExpanded: Bool = false
    let children: [SidebarItem]?

    init(title: String, identifier: String, iconName: String, children: [SidebarItem]? = nil) {
        self.title = title
        self.identifier = identifier
        self.iconName = iconName
        self.children = children
    }
}

/// Sidebar listing the top-level sections of the app with expandable submenus.
final class SidebarViewController: NSViewController {
    private var rootItems: [SidebarItem] = []
    private var flattenedItems: [(item: SidebarItem, depth: Int, isParent: Bool)] = []
    private let tableView = NSTableView()
    private var selectedIdentifier: String = "uninstall"

    /// Called when the user selects an item, with the item identifier.
    var onSelect: ((String) -> Void)?

    override func loadView() {
        rebuildItems()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Section"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }

    private func rebuildItems() {
        rootItems = [
            SidebarItem(title: L("sidebar.uninstall"), identifier: "uninstall", iconName: "trash.fill"),
            SidebarItem(title: L("sidebar.cleanup"), identifier: "cleanup", iconName: "trash.circle.fill", children: [
                SidebarItem(title: L("sidebar.clean.caches"), identifier: "clean.caches", iconName: "folder.fill.badge.gearshape"),
                SidebarItem(title: L("sidebar.clean.logs"), identifier: "clean.logs", iconName: "doc.text.fill"),
                SidebarItem(title: L("sidebar.clean.leftovers"), identifier: "clean.leftovers", iconName: "tray.2.fill"),
                SidebarItem(title: L("sidebar.clean.largeFiles"), identifier: "clean.largeFiles", iconName: "externaldrive.fill"),
            ]),
            SidebarItem(title: L("sidebar.developer"), identifier: "developer", iconName: "hammer.fill", children: [
                SidebarItem(title: L("sidebar.dev.xcode"), identifier: "dev.xcode", iconName: "app.fill"),
                SidebarItem(title: L("sidebar.dev.homebrew"), identifier: "dev.homebrew", iconName: "mug.fill"),
                SidebarItem(title: L("sidebar.dev.node"), identifier: "dev.node", iconName: "cube.fill"),
                SidebarItem(title: L("sidebar.dev.python"), identifier: "dev.python", iconName: "chevron.left.forwardslash.chevron.right"),
                SidebarItem(title: L("sidebar.dev.rust"), identifier: "dev.rust", iconName: "gearshape.fill"),
                SidebarItem(title: L("sidebar.dev.go"), identifier: "dev.go", iconName: "cylinder.fill"),
                SidebarItem(title: L("sidebar.dev.jetbrains"), identifier: "dev.jetbrains", iconName: "terminal.fill"),
                SidebarItem(title: L("sidebar.dev.vscode"), identifier: "dev.vscode", iconName: "chevron.left.forwardslash.chevron.right"),
                SidebarItem(title: L("sidebar.dev.containers"), identifier: "dev.containers", iconName: "cube.box.fill"),
            ])
        ]
        // Expand System Junk and Developer Junk by default
        rootItems[1].isExpanded = true
        rootItems[2].isExpanded = true
        flattenItems()
    }

    private func flattenItems() {
        flattenedItems = []
        for item in rootItems {
            flattenItem(item, depth: 0)
        }
    }

    private func flattenItem(_ item: SidebarItem, depth: Int) {
        let isParent = item.children != nil
        flattenedItems.append((item: item, depth: depth, isParent: isParent))

        if isParent && item.isExpanded, let children = item.children {
            for child in children {
                flattenedItems.append((item: child, depth: depth + 1, isParent: false))
            }
        }
    }

    func selectIdentifier(_ identifier: String) {
        selectedIdentifier = identifier
        // Find the row for this identifier
        for (index, entry) in flattenedItems.enumerated() {
            if entry.item.identifier == identifier {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                onSelect?(identifier)
                break
            }
        }
    }

    func reloadData() {
        rebuildItems()
        tableView.reloadData()
        // Re-select current item
        selectIdentifier(selectedIdentifier)
    }
}

extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        flattenedItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < flattenedItems.count else { return nil }
        let entry = flattenedItems[row]

        let cellId = NSUserInterfaceItemIdentifier("SectionCell-\(entry.depth)")
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell!.identifier = cellId

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cell!.addSubview(imageView)
            cell!.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell!.addSubview(textField)
            cell!.textField = textField

            let indent = CGFloat(entry.depth) * 16 + 8
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: indent),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }

        cell?.textField?.stringValue = entry.item.title
        if let imageView = cell?.imageView {
            let image = NSImage(systemSymbolName: entry.item.iconName, accessibilityDescription: nil)
            imageView.image = image
            imageView.contentTintColor = .secondaryLabelColor
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < flattenedItems.count else { return }
        let entry = flattenedItems[row]

        // If it's a parent item, toggle expansion
        if entry.isParent {
            // Find and update the root item
            for i in rootItems.indices {
                if rootItems[i].identifier == entry.item.identifier {
                    rootItems[i].isExpanded.toggle()
                    flattenItems()
                    tableView.reloadData()
                    return
                }
            }
        }

        // Otherwise, select the item
        selectedIdentifier = entry.item.identifier
        onSelect?(entry.item.identifier)
    }
}
