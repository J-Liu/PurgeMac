// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import PurgeMacCore

/// The privileged helper runs as root and moves files to Trash on behalf of the app.
/// It's launched on demand by launchd when the app connects via XPC.
let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: PurgeMacHelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()