// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

/// Settings window with tabs for General, Large Files, and About.
final class SettingsWindow: NSWindow {

    private var tabView: NSTabView!
    private var generalTab: NSView!
    private var largeFilesTab: NSView!
    private var aboutTab: NSView!
    private var languagePopup: NSPopUpButton!
    private var scanDirsTableView: NSTableView!
    private var excludedDirsTableView: NSTableView!
    private var scanDirs: [String] = []
    private var excludedDirs: [String] = []

    // Layout constants
    private let labelWidth: CGFloat = 100
    private let controlWidth: CGFloat = 200
    private let rowSpacing: CGFloat = 16

    init() {
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "settings.largeFileThresholdMB": 100,
            "settings.oldFileMonths": 12,
            "settings.oldFileMinSizeMB": 10,
            "settings.largeFileScanDirs": ["~/Downloads", "~/Documents", "~/Desktop"],
            "settings.largeFileExcludedDirs": []
        ])

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width: CGFloat = 550
        let height: CGFloat = 420
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2
        let frame = NSRect(x: x, y: y, width: width, height: height)

        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.title = L("settings.title")
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 450, height: 350)

        setupUI()
        setupKeyHandlers()
    }

    private func setupUI() {
        tabView = NSTabView(frame: contentView!.bounds.insetBy(dx: 10, dy: 10))
        tabView.autoresizingMask = [.width, .height]

        recreateTabs()

        contentView?.addSubview(tabView)

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    private func recreateTabs() {
        // Remove existing tabs
        while let tab = tabView.tabViewItems.first {
            tabView.removeTabViewItem(tab)
        }

        generalTab = createGeneralTab()
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L("settings.tab.general")
        generalItem.view = generalTab
        tabView.addTabViewItem(generalItem)

        largeFilesTab = createLargeFilesTab()
        let largeFilesItem = NSTabViewItem(identifier: "largeFiles")
        largeFilesItem.label = L("settings.tab.largeFiles")
        largeFilesItem.view = largeFilesTab
        tabView.addTabViewItem(largeFilesItem)

        aboutTab = createAboutTab()
        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = L("settings.tab.about")
        aboutItem.view = aboutTab
        tabView.addTabViewItem(aboutItem)

        // Update window title
        self.title = L("settings.title")
    }

    @objc private func languageDidChange() {
        recreateTabs()
    }

    // MARK: - Layout Helpers

    private func wrapInTopAlignedContainer(_ stack: NSStackView) -> NSView {
        let container = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    private func makeRow(label: String, control: NSView) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelField, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func makeVerticalStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = rowSpacing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }

    // MARK: - General Tab

    private func createGeneralTab() -> NSView {
        let stack = makeVerticalStack()

        // Row: Language
        languagePopup = NSPopUpButton()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.displayName)
            languagePopup.lastItem?.representedObject = language
        }
        let current = LocalizationManager.shared.currentLanguage
        if let index = AppLanguage.allCases.firstIndex(of: current) {
            languagePopup.selectItem(at: index)
        }
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        languagePopup.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
        stack.addArrangedSubview(makeRow(label: L("settings.language"), control: languagePopup))

        // Restart hint label
        let restartLabel = NSTextField(labelWithString: L("settings.restartRequired"))
        restartLabel.textColor = .secondaryLabelColor
        restartLabel.font = .systemFont(ofSize: 11)
        restartLabel.translatesAutoresizingMaskIntoConstraints = false
        restartLabel.isHidden = true
        restartLabel.identifier = NSUserInterfaceItemIdentifier("restartLabel")
        stack.addArrangedSubview(restartLabel)

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - Large Files Tab

    private func createLargeFilesTab() -> NSView {
        let stack = makeVerticalStack()

        // Large file threshold
        let largeFileThresholdField = NSTextField()
        largeFileThresholdField.placeholderString = "100"
        largeFileThresholdField.stringValue = String(UserDefaults.standard.integer(forKey: "settings.largeFileThresholdMB"))
        largeFileThresholdField.target = self
        largeFileThresholdField.action = #selector(largeFileThresholdChanged(_:))
        largeFileThresholdField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let mbLabel = NSTextField(labelWithString: "MB")
        let thresholdRow = NSStackView(views: [largeFileThresholdField, mbLabel])
        thresholdRow.orientation = .horizontal
        thresholdRow.spacing = 4
        stack.addArrangedSubview(makeRow(label: L("settings.largeFiles.threshold"), control: thresholdRow))

        // Old file months
        let oldFileMonthsField = NSTextField()
        oldFileMonthsField.placeholderString = "12"
        oldFileMonthsField.stringValue = String(UserDefaults.standard.integer(forKey: "settings.oldFileMonths"))
        oldFileMonthsField.target = self
        oldFileMonthsField.action = #selector(oldFileMonthsChanged(_:))
        oldFileMonthsField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let monthsLabel = NSTextField(labelWithString: L("settings.largeFiles.months"))
        let monthsRow = NSStackView(views: [oldFileMonthsField, monthsLabel])
        monthsRow.orientation = .horizontal
        monthsRow.spacing = 4
        stack.addArrangedSubview(makeRow(label: L("settings.largeFiles.oldFiles"), control: monthsRow))

        // Old file minimum size
        let oldFileMinSizeField = NSTextField()
        oldFileMinSizeField.placeholderString = "10"
        oldFileMinSizeField.stringValue = String(UserDefaults.standard.integer(forKey: "settings.oldFileMinSizeMB"))
        oldFileMinSizeField.target = self
        oldFileMinSizeField.action = #selector(oldFileMinSizeChanged(_:))
        oldFileMinSizeField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let minMbLabel = NSTextField(labelWithString: "MB")
        let minSizeRow = NSStackView(views: [oldFileMinSizeField, minMbLabel])
        minSizeRow.orientation = .horizontal
        minSizeRow.spacing = 4
        stack.addArrangedSubview(makeRow(label: L("settings.largeFiles.oldMinSize"), control: minSizeRow))

        // Scan directories section
        let scanDirsLabel = NSTextField(labelWithString: L("settings.largeFiles.scanDirs"))
        scanDirsLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(scanDirsLabel)

        // Load scan dirs
        scanDirs = UserDefaults.standard.stringArray(forKey: "settings.largeFileScanDirs") ?? ["~/Downloads", "~/Documents", "~/Desktop"]

        // Scan directories table
        scanDirsTableView = NSTableView()
        scanDirsTableView.delegate = self
        scanDirsTableView.dataSource = self
        scanDirsTableView.usesAlternatingRowBackgroundColors = true
        let scanDirColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        scanDirColumn.title = ""
        scanDirColumn.width = 460
        scanDirsTableView.addTableColumn(scanDirColumn)

        let scanScroll = NSScrollView()
        scanScroll.documentView = scanDirsTableView
        scanScroll.hasVerticalScroller = true
        scanScroll.translatesAutoresizingMaskIntoConstraints = false
        scanScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Add/Remove buttons for scan dirs
        let addScanDirButton = NSButton(title: L("settings.button.add"), target: self, action: #selector(addScanDirClicked))
        addScanDirButton.bezelStyle = .rounded
        let removeScanDirButton = NSButton(title: L("settings.button.remove"), target: self, action: #selector(removeScanDirClicked))
        removeScanDirButton.bezelStyle = .rounded
        let scanButtonsRow = NSStackView(views: [addScanDirButton, removeScanDirButton])
        scanButtonsRow.orientation = .horizontal
        scanButtonsRow.spacing = 8

        let scanDirsContainer = NSStackView(views: [scanScroll, scanButtonsRow])
        scanDirsContainer.orientation = .vertical
        scanDirsContainer.spacing = 8
        stack.addArrangedSubview(scanDirsContainer)

        // Excluded directories section
        let excludedLabel = NSTextField(labelWithString: L("settings.largeFiles.excludedDirs"))
        excludedLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(excludedLabel)

        // Load excluded dirs
        excludedDirs = UserDefaults.standard.stringArray(forKey: "settings.largeFileExcludedDirs") ?? []

        // Excluded directories table
        excludedDirsTableView = NSTableView()
        excludedDirsTableView.delegate = self
        excludedDirsTableView.dataSource = self
        excludedDirsTableView.usesAlternatingRowBackgroundColors = true
        let excludedDirColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        excludedDirColumn.title = ""
        excludedDirColumn.width = 460
        excludedDirsTableView.addTableColumn(excludedDirColumn)

        let excludedScroll = NSScrollView()
        excludedScroll.documentView = excludedDirsTableView
        excludedScroll.hasVerticalScroller = true
        excludedScroll.translatesAutoresizingMaskIntoConstraints = false
        excludedScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Add/Remove buttons for excluded dirs
        let addExcludedDirButton = NSButton(title: L("settings.button.add"), target: self, action: #selector(addExcludedDirClicked))
        addExcludedDirButton.bezelStyle = .rounded
        let removeExcludedDirButton = NSButton(title: L("settings.button.remove"), target: self, action: #selector(removeExcludedDirClicked))
        removeExcludedDirButton.bezelStyle = .rounded
        let excludedButtonsRow = NSStackView(views: [addExcludedDirButton, removeExcludedDirButton])
        excludedButtonsRow.orientation = .horizontal
        excludedButtonsRow.spacing = 8

        let excludedDirsContainer = NSStackView(views: [excludedScroll, excludedButtonsRow])
        excludedDirsContainer.orientation = .vertical
        excludedDirsContainer.spacing = 8
        stack.addArrangedSubview(excludedDirsContainer)

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - About Tab

    private func createAboutTab() -> NSView {
        let container = NSView()

        let appIcon = NSImageView()
        if let icnsPath = Bundle.main.path(forResource: "PurgeMac", ofType: "icns"),
           let image = NSImage(contentsOfFile: icnsPath) {
            appIcon.image = image
        } else if let image = NSImage(named: "NSApplicationIcon") {
            appIcon.image = image
        } else {
            appIcon.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            appIcon.contentTintColor = .controlAccentColor
        }
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 80).isActive = true
        container.addSubview(appIcon)

        let nameLabel = NSTextField(labelWithString: "PurgeMac")
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let versionLabel = NSTextField(labelWithString: "\(L("settings.about.version")) \(version)")
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(versionLabel)

        let copyrightLabel = NSTextField(labelWithString: L("settings.about.copyright"))
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(copyrightLabel)

        let githubButton = NSButton(title: "github.com/J-Liu/PurgeMac", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(githubButton)

        let checkUpdatesButton = NSButton(title: L("menu.checkForUpdates"), target: self, action: #selector(checkForUpdatesNow))
        checkUpdatesButton.bezelStyle = .rounded
        checkUpdatesButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkUpdatesButton)

        NSLayoutConstraint.activate([
            appIcon.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            appIcon.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            versionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            copyrightLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            copyrightLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            githubButton.topAnchor.constraint(equalTo: copyrightLabel.bottomAnchor, constant: 24),
            githubButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            checkUpdatesButton.topAnchor.constraint(equalTo: githubButton.bottomAnchor, constant: 12),
            checkUpdatesButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            checkUpdatesButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        return container
    }

    // MARK: - Key Handlers

    private func setupKeyHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if event.keyCode == 53 { // Esc
                self.close()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.keyCode == 13 { // Cmd+W
                self.close()
                return nil
            }
            return event
        }
    }

    // MARK: - Actions

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let selected = sender.selectedItem?.representedObject as? AppLanguage else { return }
        LocalizationManager.shared.currentLanguage = selected

        if let restartLabel = generalTab.subviews.first(where: { $0.identifier?.rawValue == "restartLabel" }) as? NSTextField {
            restartLabel.isHidden = false
        }
    }

    @objc private func largeFileThresholdChanged(_ sender: NSTextField) {
        let value = Int(sender.stringValue) ?? 100
        UserDefaults.standard.set(max(1, value), forKey: "settings.largeFileThresholdMB")
    }

    @objc private func oldFileMonthsChanged(_ sender: NSTextField) {
        let value = Int(sender.stringValue) ?? 12
        UserDefaults.standard.set(max(1, value), forKey: "settings.oldFileMonths")
    }

    @objc private func oldFileMinSizeChanged(_ sender: NSTextField) {
        let value = Int(sender.stringValue) ?? 10
        UserDefaults.standard.set(max(1, value), forKey: "settings.oldFileMinSizeMB")
    }

    @objc private func addScanDirClicked() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("settings.selectDirectory")

        if panel.runModal() == .OK {
            for url in panel.urls {
                let path = url.path
                if !scanDirs.contains(path) {
                    scanDirs.append(path)
                }
            }
            saveScanDirs()
            scanDirsTableView.reloadData()
        }
    }

    @objc private func removeScanDirClicked() {
        let selected = scanDirsTableView.selectedRowIndexes
        var newDirs: [String] = []
        for (index, dir) in scanDirs.enumerated() {
            if !selected.contains(index) {
                newDirs.append(dir)
            }
        }
        scanDirs = newDirs
        saveScanDirs()
        scanDirsTableView.reloadData()
    }

    private func saveScanDirs() {
        UserDefaults.standard.set(scanDirs, forKey: "settings.largeFileScanDirs")
    }

    @objc private func addExcludedDirClicked() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("settings.selectDirectory")

        if panel.runModal() == .OK {
            for url in panel.urls {
                let path = url.path
                if !excludedDirs.contains(path) {
                    excludedDirs.append(path)
                }
            }
            saveExcludedDirs()
            excludedDirsTableView.reloadData()
        }
    }

    @objc private func removeExcludedDirClicked() {
        let selected = excludedDirsTableView.selectedRowIndexes
        var newDirs: [String] = []
        for (index, dir) in excludedDirs.enumerated() {
            if !selected.contains(index) {
                newDirs.append(dir)
            }
        }
        excludedDirs = newDirs
        saveExcludedDirs()
        excludedDirsTableView.reloadData()
    }

    private func saveExcludedDirs() {
        UserDefaults.standard.set(excludedDirs, forKey: "settings.largeFileExcludedDirs")
    }

    @objc private func checkForUpdatesNow() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.checkForUpdates()
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/J-Liu/PurgeMac") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Table View Data Source and Delegate

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === scanDirsTableView {
            return scanDirs.count
        }
        return excludedDirs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let path: String
        if tableView === scanDirsTableView {
            guard row < scanDirs.count else { return nil }
            path = scanDirs[row]
        } else {
            guard row < excludedDirs.count else { return nil }
            path = excludedDirs[row]
        }

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // Use folder icon
        imageView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        imageView.contentTintColor = .systemBlue
        imageView.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(imageView)

        let textField = NSTextField(labelWithString: path)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}