// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Foundation
import PurgeMacCore

/// Handles incoming XPC connections and validates the client.
final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the connecting process is our app
        guard isValidClient(newConnection) else {
            NSLog("PurgeMacHelper: rejecting connection from invalid client")
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: PurgeMacHelperProtocol.self)
        let service = HelperService()
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }

    private func isValidClient(_ connection: NSXPCConnection) -> Bool {
        // Get the connecting process's PID
        let pid = connection.processIdentifier

        // Get the bundle identifier of the connecting process
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleIdentifier = app.bundleIdentifier else {
            return false
        }

        // Check if it's our app
        return bundleIdentifier == "io.github.jia-liu.PurgeMac"
    }
}