// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Constants shared between the app and the privileged helper.
public enum PurgeMacHelperConstants {
    /// The helper's mach service name and bundle identifier.
    public static let machServiceName = "io.github.jia-liu.PurgeMac.helper"

    /// The helper's build version. Bump when behavior changes.
    public static let version = "1"

    /// The daemon property list name for SMAppService.
    public static let daemonPlistName = "io.github.jia-liu.PurgeMac.helper.plist"

    /// The team identifier for code signing.
    /// TODO: Replace with your actual team ID when distributing.
    public static let teamIdentifier = "YOUR_TEAM_ID"

    /// Code signing requirement for the client (app).
    public static var clientRequirement: String {
        "identifier \"io.github.jia-liu.PurgeMac\" and anchor apple generic and " +
        "certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    /// Code signing requirement for the helper.
    public static var helperRequirement: String {
        "identifier \"\(machServiceName)\" and anchor apple generic and " +
        "certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }
}

/// The privileged operations the helper exposes over XPC.
@objc(PurgeMacHelperProtocol)
public protocol PurgeMacHelperProtocol {
    /// Moves paths to the user's Trash with root privileges.
    /// - Parameters:
    ///   - paths: Paths to move to Trash
    ///   - reply: Callback with successfully moved paths
    func moveToTrash(paths: [String], withReply reply: @escaping ([String]) -> Void)

    /// Returns the helper's version.
    func helperVersion(withReply reply: @escaping (String) -> Void)
}