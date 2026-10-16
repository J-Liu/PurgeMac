// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Root split view controller with a sidebar and a content area.
final class MainSplitViewController: NSSplitViewController {
    private let sidebarViewController = SidebarViewController()
    private let uninstallViewController = UninstallViewController()
    private let cleanViewController = CleanViewController()
    private var currentIndex: Int = 0

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

        sidebarViewController.onSelect = { [weak self] index in
            self?.currentIndex = index
            self?.showContent(for: index)
        }

        // Select the first sidebar entry once the view is ready.
        DispatchQueue.main.async { [weak self] in
            self?.sidebarViewController.selectRow(0)
        }

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    private func showContent(for index: Int) {
        guard splitViewItems.count > 1 else { return }
        switch index {
        case 0:
            splitViewItems[1].viewController = uninstallViewController
        default:
            splitViewItems[1].viewController = cleanViewController
        }
    }

    @objc private func languageDidChange() {
        // Refresh sidebar
        sidebarViewController.reloadData()
        // Refresh current view controller
        if currentIndex == 0 {
            uninstallViewController.reloadData()
        } else {
            cleanViewController.reloadData()
        }
    }
}
