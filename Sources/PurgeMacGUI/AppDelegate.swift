// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

/// Application delegate that shows the primary window and configures updates.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var settingsWindow: SettingsWindow?

    /// Standard Sparkle updater controller used for the "Check for Updates" menu item.
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        createMainWindow()
        setupKeyHandlers()
        configureUpdateCheck()
        applySavedTheme()

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

    private func applySavedTheme() {
        let savedTheme = UserDefaults.standard.integer(forKey: "settings.theme")
        switch savedTheme {
        case 1:
            NSApp.appearance = NSAppearance(named: .aqua)
        case 2:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    private func configureUpdateCheck() {
        // Disable Sparkle's built-in automatic check - we handle it ourselves
        updaterController.updater.automaticallyChecksForUpdates = false

        // Check if we should check for updates based on frequency setting
        guard shouldCheckForUpdates() else { return }

        // Delay to let the app settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Use background check - only shows UI if update is found
            self?.updaterController.updater.checkForUpdatesInBackground()
            self?.recordUpdateCheck()
        }
    }

    private func shouldCheckForUpdates() -> Bool {
        let savedInterval = UserDefaults.standard.double(forKey: "settings.updateCheckInterval")

        // Default to weekly if not set
        let interval: TimeInterval
        if !UserDefaults.standard.bool(forKey: "settings.updateCheckIntervalSet") {
            interval = 604800 // Weekly default
            UserDefaults.standard.set(true, forKey: "settings.updateCheckIntervalSet")
            UserDefaults.standard.set(interval, forKey: "settings.updateCheckInterval")
        } else {
            interval = savedInterval
        }

        // Never: don't check
        if interval < 0 { return false }

        // At startup: always check
        if interval == 0 { return true }

        // Periodic: check if enough time has passed
        let lastCheck = UserDefaults.standard.string(forKey: "settings.lastUpdateCheck") ?? ""
        guard !lastCheck.isEmpty else { return true }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let lastDate = formatter.date(from: lastCheck) else { return true }

        let now = Date()
        let timeSinceLastCheck = now.timeIntervalSince(lastDate)

        return timeSinceLastCheck >= interval
    }

    private func recordUpdateCheck() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        UserDefaults.standard.set(formatter.string(from: Date()), forKey: "settings.lastUpdateCheck")
    }

    private func createMainWindow() {
        let splitViewController = MainSplitViewController()
        let window = NSWindow(contentViewController: splitViewController)
        window.title = "PurgeMac"
        window.setContentSize(NSSize(width: 1100, height: 680))
        window.minSize = NSSize(width: 800, height: 520)
        window.center()
        window.delegate = self
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
                } else if let window = self.window, window.isVisible {
                    self.handleWindowClose(window)
                }
                return nil
            }
            return event
        }
    }

    /// Handle window close based on user preference.
    private func handleWindowClose(_ window: NSWindow) {
        let quitOnClose = UserDefaults.standard.bool(forKey: "settings.quitOnClose")
        if quitOnClose {
            NSApp.terminate(nil)
        } else {
            window.orderOut(nil)
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
        UserDefaults.standard.bool(forKey: "settings.quitOnClose")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            window?.makeKeyAndOrderFront(nil)
        } else {
            createMainWindow()
        }
        return true
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
            action: #selector(manualCheckForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let uninstallItem = NSMenuItem(
            title: L("menu.uninstall"),
            action: #selector(uninstallSelf),
            keyEquivalent: ""
        )
        uninstallItem.target = self
        menu.addItem(uninstallItem)

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

    @objc private func manualCheckForUpdates() {
        updaterController.checkForUpdates(nil)
        recordUpdateCheck()
    }

    @objc func uninstallSelf() {
        let alert = NSAlert()
        alert.messageText = L("uninstall.self.title")
        alert.informativeText = L("uninstall.self.message")
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("uninstall.self.uninstall"))
        alert.addButton(withTitle: L("uninstall.alert.confirm.cancel"))
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        // Create uninstall script
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("uninstall_purgemac.sh")
        let appPath = Bundle.main.bundlePath
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jialiu.purgemac"
        
        // Use osascript to move to Trash
        let script = """
        #!/bin/bash
        # Wait for app to quit
        sleep 2
        
        # Move app bundle to Trash
        osascript -e "tell application \\"Finder\\" to move POSIX file \\"\(appPath)\\" to trash" 2>/dev/null
        
        # Move preferences to Trash
        osascript -e "tell application \\"Finder\\" to move POSIX file \\"$HOME/Library/Preferences/\(bundleID).plist\\" to trash" 2>/dev/null
        
        # Move caches to Trash
        osascript -e "tell application \\"Finder\\" to move POSIX file \\"$HOME/Library/Caches/\(bundleID)\\" to trash" 2>/dev/null
        
        # Move application support to Trash
        osascript -e "tell application \\"Finder\\" to move POSIX file \\"$HOME/Library/Application Support/PurgeMac\\" to trash" 2>/dev/null
        
        # Move container to Trash (if exists)
        osascript -e "tell application \\"Finder\\" to move POSIX file \\"$HOME/Library/Containers/\(bundleID)\\" to trash" 2>/dev/null
        
        # Delete this script
        rm -f "\(scriptPath.path)"
        """
        
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            
            // Make script executable
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/chmod")
            task.arguments = ["+x", scriptPath.path]
            try task.run()
            task.waitUntilExit()
            
            // Launch script and quit
            let scriptTask = Process()
            scriptTask.executableURL = URL(fileURLWithPath: scriptPath.path)
            try scriptTask.run()
            
            // Quit app
            NSApp.terminate(nil)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = L("uninstall.self.failed")
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: L("uninstall.alert.ok"))
            errorAlert.runModal()
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window else { return true }
        handleWindowClose(sender)
        return false
    }
}
