// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Jia Liu

import Foundation

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
    static let largeFilesSettingsChanged = Notification.Name("largeFilesSettingsChanged")
}

/// Supported languages for the app
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .system:
            return localizedStrings[.english]?["settings.language.system"] ?? "System Default"
        case .english:
            return localizedStrings[.english]?["settings.language.english"] ?? "English"
        case .simplifiedChinese:
            return localizedStrings[.simplifiedChinese]?["settings.language.simplifiedChinese"] ?? "简体中文"
        case .traditionalChinese:
            return localizedStrings[.traditionalChinese]?["settings.language.traditionalChinese"] ?? "繁體中文"
        }
    }
}

/// Manages app localization settings
final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "appLanguage"

    var currentLanguage: AppLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: languageKey),
               let language = AppLanguage(rawValue: rawValue) {
                return language
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            // Post notification for UI updates
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private init() {}

    func localizedString(_ key: String) -> String {
        let language = currentLanguage == .system ? systemLanguage() : currentLanguage
        return localizedStrings[language]?[key] ?? key
    }

    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }

    private func systemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
            return .simplifiedChinese
        } else if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
            return .traditionalChinese
        }
        return .english
    }
}

/// Global helper for localized strings
func L(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    return LocalizationManager.shared.localizedString(key, arguments)
}

// MARK: - Localized Strings Dictionary

private let localizedStrings: [AppLanguage: [String: String]] = [
    .english: [
        // Settings
        "settings.title": "Settings",
        "settings.tab.general": "General",
        "settings.tab.largeFiles": "Large Files",
        "settings.tab.about": "About",
        "settings.language": "Language:",
        "settings.language.system": "System Default",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "Simplified Chinese",
        "settings.language.traditionalChinese": "Traditional Chinese",
        "settings.about.version": "Version",
        "settings.about.copyright": "Copyright © 2026 Jia Liu",
        "settings.largeFiles.section": "Large Files Settings",
        "settings.largeFiles.threshold": "Size Threshold:",
        "settings.largeFiles.oldFiles": "Files older than:",
        "settings.largeFiles.months": "months, larger than",
        "settings.largeFiles.oldMinSize": "MB",
        "settings.largeFiles.scanDirs": "Scan Directories",
        "settings.largeFiles.directories": "Directories:",
        "settings.largeFiles.excludedDirs": "Excluded Directories",
        "settings.largeFiles.excluded": "Exclude:",
        "settings.button.add": "Add",
        "settings.button.remove": "Remove",
        "settings.selectDirectory": "Select a directory",

        // Sidebar
        "sidebar.uninstall": "Uninstaller",
        "sidebar.cleanup": "System Junk",
        "sidebar.clean.caches": "System Caches",
        "sidebar.clean.logs": "Logs & Errors",
        "sidebar.clean.leftovers": "App Leftovers",
        "sidebar.clean.largeFiles": "Large Files",
        "sidebar.developer": "Developer Junk",
        "sidebar.dev.xcode": "Xcode",
        "sidebar.dev.homebrew": "Homebrew",
        "sidebar.dev.node": "Node.js",
        "sidebar.dev.python": "Python",
        "sidebar.dev.rust": "Rust",
        "sidebar.dev.go": "Go",
        "sidebar.dev.jetbrains": "JetBrains",
        "sidebar.dev.vscode": "VS Code",
        "sidebar.dev.containers": "Containers",

        // Uninstall View
        "uninstall.search.placeholder": "Search by name or bundle ID",
        "uninstall.column.icon": "Icon",
        "uninstall.column.name": "Name",
        "uninstall.column.version": "Version",
        "uninstall.column.bundleID": "Bundle ID",
        "uninstall.leftover.title": "Related Files (unchecked by default)",
        "uninstall.selectAll": "Select All Related Files",
        "uninstall.scanning.leftovers": "Scanning for related files...",
        "uninstall.scanning.apps": "Scanning for installed apps...",
        "uninstall.select.prompt": "Select an app to inspect its related files.",
        "uninstall.leftover.none": "No related files found.",
        "uninstall.leftover.count": "%d related file(s) found.",
        "uninstall.button.uninstall": "Uninstall",
        "uninstall.alert.noApp.title": "No app selected",
        "uninstall.alert.noApp.message": "Select an application in the list first.",
        "uninstall.alert.confirm.title": "Uninstall %@?",
        "uninstall.alert.confirm.message": "The application will be moved to the Trash.",
        "uninstall.alert.confirm.message.withLeftovers": "The application will be moved to the Trash.\n\n%d related file(s) will also be moved to the Trash.",
        "uninstall.alert.confirm.uninstall": "Uninstall",
        "uninstall.alert.confirm.cancel": "Cancel",
        "uninstall.result.moved": "Moved to Trash: %@",
        "uninstall.result.freed": "Freed %@",
        "uninstall.result.partial": "%d related file(s) could not be removed.",
        "uninstall.alert.failed.title": "Uninstall failed",
        "uninstall.alert.ok": "OK",

        // Clean View
        "clean.status.initial": "Click Scan next to a category to inspect it.",
        "clean.column.category": "Category",
        "clean.column.size": "Eligible Space",
        "clean.column.action": "",
        "clean.column.items": "Items",
        "clean.button.scan": "Scan",
        "clean.button.clean": "Clean",
        "clean.status.scanning": "Scanning %@...",
        "clean.status.found": "%d item(s) found for %@.",
        "clean.status.largeFiles": "%d large file(s) found (list-only).",
        "clean.status.freed": "Freed %@.",
        "clean.alert.noSelection.title": "No items selected",
        "clean.alert.noSelection.message": "Check the items you want to clean first.",
        "clean.alert.confirm.title": "Clean %d item(s)?",
        "clean.alert.confirm.message": "Selected items will be moved to the Trash.",
        "clean.alert.confirm.clean": "Clean",
        "clean.button.moveToTrash": "Move to Trash",
        "clean.selectedSize": "%@ will be freed",
        "clean.alert.move.title": "Move this file to the Trash?",
        "clean.selectAll": "Select All",

        // Junk Categories
        "junk.userCaches": "User Caches",
        "junk.logs": "Logs",
        "junk.leftovers": "App Leftovers",
        "junk.largeFiles": "Large Files",
        "junk.trash": "Trash",
        "junk.devXcode": "Xcode",
        "junk.devHomebrew": "Homebrew",
        "junk.devNode": "Node.js",
        "junk.devPython": "Python",
        "junk.devRust": "Rust",
        "junk.devGo": "Go",
        "junk.devJetBrains": "JetBrains",
        "junk.devVSCode": "VS Code",
        "junk.devContainers": "Containers",
        "junk.notScanned": "Not scanned",

        // Main Menu
        "menu.about": "About %@",
        "menu.checkForUpdates": "Check for Updates...",
        "menu.quit": "Quit %@",
        "menu.preferences": "Preferences...",
    ],

    .simplifiedChinese: [
        // Settings
        "settings.title": "设置",
        "settings.tab.general": "通用",
        "settings.tab.largeFiles": "大文件",
        "settings.tab.about": "关于",
        "settings.language": "语言：",
        "settings.language.system": "系统默认",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "简体中文",
        "settings.language.traditionalChinese": "繁體中文",
        "settings.about.version": "版本",
        "settings.about.copyright": "版权所有 © 2026 Jia Liu",
        "settings.largeFiles.section": "大文件设置",
        "settings.largeFiles.threshold": "大小阈值：",
        "settings.largeFiles.oldFiles": "文件超过：",
        "settings.largeFiles.months": "个月，大于",
        "settings.largeFiles.oldMinSize": "MB",
        "settings.largeFiles.scanDirs": "扫描目录",
        "settings.largeFiles.directories": "目录：",
        "settings.largeFiles.excludedDirs": "忽略目录",
        "settings.largeFiles.excluded": "忽略：",
        "settings.button.add": "添加",
        "settings.button.remove": "移除",
        "settings.selectDirectory": "选择目录",

        // Sidebar
        "sidebar.uninstall": "卸载器",
        "sidebar.cleanup": "系统垃圾",
        "sidebar.clean.caches": "系统缓存",
        "sidebar.clean.logs": "日志和错误信息",
        "sidebar.clean.leftovers": "应用残留",
        "sidebar.clean.largeFiles": "大文件",
        "sidebar.developer": "开发者垃圾",
        "sidebar.dev.xcode": "Xcode",
        "sidebar.dev.homebrew": "Homebrew",
        "sidebar.dev.node": "Node.js",
        "sidebar.dev.python": "Python",
        "sidebar.dev.rust": "Rust",
        "sidebar.dev.go": "Go",
        "sidebar.dev.jetbrains": "JetBrains",
        "sidebar.dev.vscode": "VS Code",
        "sidebar.dev.containers": "容器",

        // Uninstall View
        "uninstall.search.placeholder": "按名称或 Bundle ID 搜索",
        "uninstall.column.icon": "图标",
        "uninstall.column.name": "名称",
        "uninstall.column.version": "版本",
        "uninstall.column.bundleID": "Bundle ID",
        "uninstall.leftover.title": "相关文件（默认未选中）",
        "uninstall.selectAll": "全选相关文件",
        "uninstall.scanning.leftovers": "正在扫描相关文件...",
        "uninstall.scanning.apps": "正在扫描已安装应用...",
        "uninstall.select.prompt": "选择一个应用以查看其相关文件。",
        "uninstall.leftover.none": "未找到相关文件。",
        "uninstall.leftover.count": "找到 %d 个相关文件。",
        "uninstall.button.uninstall": "卸载",
        "uninstall.alert.noApp.title": "未选择应用",
        "uninstall.alert.noApp.message": "请先从列表中选择一个应用。",
        "uninstall.alert.confirm.title": "卸载 %@？",
        "uninstall.alert.confirm.message": "该应用将被移至废纸篓。",
        "uninstall.alert.confirm.message.withLeftovers": "该应用将被移至废纸篓。\n\n%d 个相关文件也将被移至废纸篓。",
        "uninstall.alert.confirm.uninstall": "卸载",
        "uninstall.alert.confirm.cancel": "取消",
        "uninstall.result.moved": "已移至废纸篓：%@",
        "uninstall.result.freed": "释放了 %@",
        "uninstall.result.partial": "%d 个相关文件无法删除。",
        "uninstall.alert.failed.title": "卸载失败",
        "uninstall.alert.ok": "确定",

        // Clean View
        "clean.status.initial": "点击类别旁的扫描按钮进行检查。",
        "clean.column.category": "类别",
        "clean.column.size": "可释放空间",
        "clean.column.action": "",
        "clean.column.items": "项目",
        "clean.button.scan": "扫描",
        "clean.button.clean": "清理",
        "clean.status.scanning": "正在扫描 %@...",
        "clean.status.found": "在 %@ 中找到 %d 个项目。",
        "clean.status.largeFiles": "找到 %d 个大文件（仅列出）。",
        "clean.status.freed": "释放了 %@。",
        "clean.alert.noSelection.title": "未选择项目",
        "clean.alert.noSelection.message": "请先勾选要清理的项目。",
        "clean.alert.confirm.title": "清理 %d 个项目？",
        "clean.alert.confirm.message": "选中的项目将被移至废纸篓。",
        "clean.alert.confirm.clean": "清理",
        "clean.button.moveToTrash": "移至废纸篓",
        "clean.selectedSize": "将释放 %@",
        "clean.alert.move.title": "将此文件移至废纸篓？",
        "clean.selectAll": "全选",

        // Junk Categories
        "junk.userCaches": "用户缓存",
        "junk.logs": "日志文件",
        "junk.leftovers": "应用残留",
        "junk.largeFiles": "大文件",
        "junk.trash": "废纸篓",
        "junk.devXcode": "Xcode",
        "junk.devHomebrew": "Homebrew",
        "junk.devNode": "Node.js",
        "junk.devPython": "Python",
        "junk.devRust": "Rust",
        "junk.devGo": "Go",
        "junk.devJetBrains": "JetBrains",
        "junk.devVSCode": "VS Code",
        "junk.devContainers": "容器",
        "junk.notScanned": "未扫描",

        // Main Menu
        "menu.about": "关于 %@",
        "menu.checkForUpdates": "检查更新...",
        "menu.quit": "退出 %@",
        "menu.preferences": "偏好设置...",
    ],

    .traditionalChinese: [
        // Settings
        "settings.title": "設定",
        "settings.tab.general": "一般",
        "settings.tab.largeFiles": "大檔案",
        "settings.tab.about": "關於",
        "settings.language": "語言：",
        "settings.language.system": "系統預設",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "简体中文",
        "settings.language.traditionalChinese": "繁體中文",
        "settings.about.version": "版本",
        "settings.about.copyright": "版權所有 © 2026 Jia Liu",
        "settings.largeFiles.section": "大檔案設定",
        "settings.largeFiles.threshold": "大小閾值：",
        "settings.largeFiles.oldFiles": "檔案超過：",
        "settings.largeFiles.months": "個月，大於",
        "settings.largeFiles.oldMinSize": "MB",
        "settings.largeFiles.scanDirs": "掃描目錄",
        "settings.largeFiles.directories": "目錄：",
        "settings.largeFiles.excludedDirs": "忽略目錄",
        "settings.largeFiles.excluded": "忽略：",
        "settings.button.add": "新增",
        "settings.button.remove": "移除",
        "settings.selectDirectory": "選擇目錄",

        // Sidebar
        "sidebar.uninstall": "卸載器",
        "sidebar.cleanup": "系統垃圾",
        "sidebar.clean.caches": "系統快取",
        "sidebar.clean.logs": "日誌和錯誤資訊",
        "sidebar.clean.leftovers": "應用程式殘留",
        "sidebar.clean.largeFiles": "大檔案",
        "sidebar.developer": "開發者垃圾",
        "sidebar.dev.xcode": "Xcode",
        "sidebar.dev.homebrew": "Homebrew",
        "sidebar.dev.node": "Node.js",
        "sidebar.dev.python": "Python",
        "sidebar.dev.rust": "Rust",
        "sidebar.dev.go": "Go",
        "sidebar.dev.jetbrains": "JetBrains",
        "sidebar.dev.vscode": "VS Code",
        "sidebar.dev.containers": "容器",

        // Uninstall View
        "uninstall.search.placeholder": "按名稱或 Bundle ID 搜尋",
        "uninstall.column.icon": "圖示",
        "uninstall.column.name": "名稱",
        "uninstall.column.version": "版本",
        "uninstall.column.bundleID": "Bundle ID",
        "uninstall.leftover.title": "相關檔案（預設未選取）",
        "uninstall.selectAll": "選取所有相關檔案",
        "uninstall.scanning.leftovers": "正在掃描相關檔案...",
        "uninstall.scanning.apps": "正在掃描已安裝應用程式...",
        "uninstall.select.prompt": "選擇一個應用程式以查看其相關檔案。",
        "uninstall.leftover.none": "未找到相關檔案。",
        "uninstall.leftover.count": "找到 %d 個相關檔案。",
        "uninstall.button.uninstall": "卸載",
        "uninstall.alert.noApp.title": "未選擇應用程式",
        "uninstall.alert.noApp.message": "請先從列表中選擇一個應用程式。",
        "uninstall.alert.confirm.title": "卸載 %@？",
        "uninstall.alert.confirm.message": "該應用程式將被移至垃圾桶。",
        "uninstall.alert.confirm.message.withLeftovers": "該應用程式將被移至垃圾桶。\n\n%d 個相關檔案也將被移至垃圾桶。",
        "uninstall.alert.confirm.uninstall": "卸載",
        "uninstall.alert.confirm.cancel": "取消",
        "uninstall.result.moved": "已移至垃圾桶：%@",
        "uninstall.result.freed": "釋放了 %@",
        "uninstall.result.partial": "%d 個相關檔案無法刪除。",
        "uninstall.alert.failed.title": "卸載失敗",
        "uninstall.alert.ok": "確定",

        // Clean View
        "clean.status.initial": "點擊類別旁的掃描按進行查。",
        "clean.column.category": "類別",
        "clean.column.size": "可釋放空間",
        "clean.column.action": "",
        "clean.column.items": "項目",
        "clean.button.scan": "掃描",
        "clean.button.clean": "清理",
        "clean.status.scanning": "正在掃描 %@...",
        "clean.status.found": "在 %@ 中找到 %d 個項目。",
        "clean.status.largeFiles": "找到 %d 個大檔案（僅列出）。",
        "clean.status.freed": "釋放了 %@。",
        "clean.alert.noSelection.title": "未選取項目",
        "clean.alert.noSelection.message": "請先勾選要清理的項目。",
        "clean.alert.confirm.title": "清理 %d 個項目？",
        "clean.alert.confirm.message": "選取的項目將被移至垃圾桶。",
        "clean.alert.confirm.clean": "清理",
        "clean.button.moveToTrash": "移至垃圾桶",
        "clean.selectedSize": "將釋放 %@",
        "clean.alert.move.title": "將此檔案移至垃圾桶？",
        "clean.selectAll": "全選",

        // Junk Categories
        "junk.userCaches": "使用者快取",
        "junk.logs": "日誌檔案",
        "junk.leftovers": "應用程式殘留",
        "junk.largeFiles": "大檔案",
        "junk.trash": "垃圾桶",
        "junk.devXcode": "Xcode",
        "junk.devHomebrew": "Homebrew",
        "junk.devNode": "Node.js",
        "junk.devPython": "Python",
        "junk.devRust": "Rust",
        "junk.devGo": "Go",
        "junk.devJetBrains": "JetBrains",
        "junk.devVSCode": "VS Code",
        "junk.devContainers": "容器",
        "junk.notScanned": "未掃描",

        // Main Menu
        "menu.about": "關於 %@",
        "menu.checkForUpdates": "檢查更新...",
        "menu.quit": "結束 %@",
        "menu.preferences": "偏好設定...",
    ]
]
