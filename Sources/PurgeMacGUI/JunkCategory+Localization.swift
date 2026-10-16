// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Jia Liu

import PurgeMacCore

extension JunkCategory {
    /// Localized display name for GUI
    var localizedDisplayName: String {
        switch self {
        case .userCaches:
            return L("junk.userCaches")
        case .logs:
            return L("junk.logs")
        case .browserCaches:
            return L("junk.browserCaches")
        case .developerCaches:
            return L("junk.developerCaches")
        case .largeFiles:
            return L("junk.largeFiles")
        case .trash:
            return L("junk.trash")
        }
    }
}
