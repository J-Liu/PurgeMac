// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import PurgeMacCore

extension JunkCategory {
    /// Localized display name for GUI
    var localizedDisplayName: String {
        switch self {
        case .userCaches: return L("junk.userCaches")
        case .logs: return L("junk.logs")
        case .leftovers: return L("junk.leftovers")
        case .largeFiles: return L("junk.largeFiles")
        case .trash: return L("junk.trash")
        case .aiModels: return L("junk.aiModels")
        case .devXcode: return L("junk.devXcode")
        case .devHomebrew: return L("junk.devHomebrew")
        case .devNode: return L("junk.devNode")
        case .devPython: return L("junk.devPython")
        case .devRust: return L("junk.devRust")
        case .devGo: return L("junk.devGo")
        case .devJetBrains: return L("junk.devJetBrains")
        case .devVSCode: return L("junk.devVSCode")
        case .devContainers: return L("junk.devContainers")
        case .devDart: return L("junk.devDart")
        case .devRuby: return L("junk.devRuby")
        case .devPhp: return L("junk.devPhp")
        case .devJava: return L("junk.devJava")
        case .devTerraform: return L("junk.devTerraform")
        case .devElectron: return L("junk.devElectron")
        case .devGit: return L("junk.devGit")
        case .devCI: return L("junk.devCI")
        case .devShell: return L("junk.devShell")
        case .devAndroid: return L("junk.devAndroid")
        case .devScala: return L("junk.devScala")
        }
    }
}
