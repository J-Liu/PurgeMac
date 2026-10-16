// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Jia Liu

import Foundation

/// Supported languages for the app
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("settings.language.system", comment: "")
        case .english:
            return NSLocalizedString("settings.language.english", comment: "")
        case .simplifiedChinese:
            return NSLocalizedString("settings.language.simplifiedChinese", comment: "")
        case .traditionalChinese:
            return NSLocalizedString("settings.language.traditionalChinese", comment: "")
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
}

/// Manages app localization settings
final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "appLanguage"
    private var currentBundle: Bundle = .main

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
            updateBundle(for: newValue)
        }
    }

    private init() {
        updateBundle(for: currentLanguage)
    }

    private func updateBundle(for language: AppLanguage) {
        guard let identifier = language.localeIdentifier,
              let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            currentBundle = .main
            return
        }
        currentBundle = bundle
    }

    func localizedString(_ key: String) -> String {
        return currentBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }
}

/// Global helper for localized strings
func L(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    return LocalizationManager.shared.localizedString(key, arguments)
}
