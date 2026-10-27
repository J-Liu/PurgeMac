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
        createMainWindow()
        setupKeyHandlers()

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )

        // Bring the app to the foreground when launched from a terminal.
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createMainWindow() {
        let splitViewController = MainSplitViewController()
        let window = NSWindow(contentViewController: splitViewController)
        window.title = "PurgeMac"
        window.setContentSize(NSSize(width: 1100, height: 680))
        window.minSize = NSSize(width: 800, height: 520)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func setupKeyHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Cmd+W for main window
            if event.modifierFlags.contains(.command) && event.keyCode == 13 {
                if self.settingsWindow?.isVisible == true {
                    self.settingsWindow?.close()
                } else if self.window?.isVisible == true {
                    self.window?.close()
                }
                return nil
            }
            return event
        }
    }

    @objc private func languageDidChange() {
        // Check if settings window is visible
        let wasSettingsVisible = settingsWindow?.isVisible ?? false

        // Recreate main menu
        setupMainMenu()
        // Recreate main window
        window?.close()
        createMainWindow()

        // Bring settings window back to front if it was visible
        if wasSettingsVisible {
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Builds the main menu with standard macOS menu items.
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appName = "PurgeMac"

        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        appMenuItem.submenu = createAppMenu(appName)

        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        fileMenuItem.submenu = createFileMenu()

        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        editMenuItem.submenu = createEditMenu()

        // View Menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        viewMenuItem.submenu = createViewMenu()

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        windowMenuItem.submenu = createWindowMenu()

        // Help Menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        helpMenuItem.submenu = createHelpMenu(appName)

        NSApp.mainMenu = mainMenu
    }

    private func createAppMenu(_ appName: String) -> NSMenu {
        let menu = NSMenu()

        let aboutItem = NSMenuItem(
            title: L("menu.about", appName),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: L("menu.preferences"),
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: L("menu.checkForUpdates"),
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: L("menu.hide", appName),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        menu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: L("menu.hideOthers"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApp
        menu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: L("menu.showAll"),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApp
        menu.addItem(showAllItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L("menu.quit", appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.file"))

        let closeWindowItem = NSMenuItem(
            title: L("menu.closeWindow"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        menu.addItem(closeWindowItem)

        return menu
    }

    private func createEditMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.edit"))

        let undoItem = NSMenuItem(
            title: L("menu.undo"),
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        menu.addItem(undoItem)

        let redoItem = NSMenuItem(
            title: L("menu.redo"),
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redoItem)

        menu.addItem(.separator())

        let cutItem = NSMenuItem(
            title: L("menu.cut"),
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        menu.addItem(cutItem)

        let copyItem = NSMenuItem(
            title: L("menu.copy"),
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: L("menu.paste"),
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        menu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(
            title: L("menu.selectAll"),
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        menu.addItem(selectAllItem)

        return menu
    }

    private func createViewMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.view"))

        let toggleSidebarItem = NSMenuItem(
            title: L("menu.toggleSidebar"),
            action: #selector(NSSplitViewController.toggleSidebar(_:)),
            keyEquivalent: "s"
        )
        toggleSidebarItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(toggleSidebarItem)

        menu.addItem(.separator())

        let enterFullScreenItem = NSMenuItem(
            title: L("menu.enterFullScreen"),
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        enterFullScreenItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(enterFullScreenItem)

        return menu
    }

    private func createWindowMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.window"))

        let minimizeItem = NSMenuItem(
            title: L("menu.minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        menu.addItem(minimizeItem)

        let zoomItem = NSMenuItem(
            title: L("menu.zoom"),
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        menu.addItem(zoomItem)

        menu.addItem(.separator())

        let bringAllToFrontItem = NSMenuItem(
            title: L("menu.bringAllToFront"),
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        bringAllToFrontItem.target = NSApp
        menu.addItem(bringAllToFrontItem)

        return menu
    }

    private func createHelpMenu(_ appName: String) -> NSMenu {
        let menu = NSMenu(title: L("menu.help"))

        let helpItem = NSMenuItem(
            title: L("menu.helpMain", appName),
            action: #selector(openHelp),
            keyEquivalent: "?"
        )
        helpItem.target = self
        menu.addItem(helpItem)

        return menu
    }

    @objc private func showAbout() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.selectTab(withIdentifier: "about")
    }

    @objc private func showPreferences() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.selectTab(withIdentifier: "general")
    }

    @objc private func openHelp() {
        if let url = URL(string: "https://github.com/J-Liu/PurgeMac") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
