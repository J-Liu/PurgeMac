// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Root split view controller with a sidebar and a content area.
final class MainSplitViewController: NSSplitViewController {
    private let sidebarViewController = SidebarViewController()
    private let uninstallViewController = UninstallViewController()
    private let cleanViewController = CleanViewController()

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
            self?.showContent(for: index)
        }

        // Select the first sidebar entry once the view is ready.
        DispatchQueue.main.async { [weak self] in
            self?.sidebarViewController.selectRow(0)
        }
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
}
