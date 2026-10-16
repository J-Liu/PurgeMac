// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

/// Application delegate that shows the primary window and configures updates.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var settingsWindow: SettingsWindow?

    /// Standard Sparkle updater controller used for the "Check for Updates" menu item.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let splitViewController = MainSplitViewController()
        let window = NSWindow(contentViewController: splitViewController)
        window.title = "PurgeMac"
        window.setContentSize(NSSize(width: 1100, height: 680))
        window.minSize = NSSize(width: 800, height: 520)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        // Bring the app to the foreground when launched from a terminal.
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Builds a minimal main menu with About, Check for Updates, and Quit.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let appName = "PurgeMac"

        let aboutItem = NSMenuItem(
            title: L("menu.about", appName),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApp
        appMenu.addItem(aboutItem)

        appMenu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: L("menu.preferences"),
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)

        appMenu.addItem(.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: L("menu.checkForUpdates"),
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        appMenu.addItem(checkForUpdatesItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L("menu.quit", appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPreferences() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
