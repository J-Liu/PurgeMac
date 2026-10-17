// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Root split view controller with a sidebar and a content area.
final class MainSplitViewController: NSSplitViewController {
    private let sidebarViewController = SidebarViewController()
    private let uninstallViewController = UninstallViewController()
    private let cleanViewController = CleanViewController()
    private var currentIdentifier: String = "uninstall"

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 260
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: uninstallViewController)
        contentItem.minimumThickness = 500
        addSplitViewItem(contentItem)

        sidebarViewController.onSelect = { [weak self] identifier in
            self?.currentIdentifier = identifier
            self?.showContent(for: identifier)
        }

        // Select the first sidebar entry once the view is ready.
        DispatchQueue.main.async { [weak self] in
            self?.sidebarViewController.selectIdentifier("uninstall")
        }

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    private func showContent(for identifier: String) {
        guard splitViewItems.count > 1 else { return }
        switch identifier {
        case "uninstall":
            splitViewItems[1].viewController = uninstallViewController
        default:
            // All clean sub-pages use CleanViewController with different modes
            splitViewItems[1].viewController = cleanViewController
            cleanViewController.setMode(identifier)
        }
    }

    @objc private func languageDidChange() {
        // Refresh sidebar
        sidebarViewController.reloadData()
        // Refresh current view controller
        if currentIdentifier == "uninstall" {
            uninstallViewController.reloadData()
        } else {
            cleanViewController.reloadData()
        }
    }
}
