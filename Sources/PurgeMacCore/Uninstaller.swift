// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

/// Errors thrown while attempting to uninstall an application.
public enum UninstallError: Error, LocalizedError {
    /// The app is not located inside `/Applications` or `~/Applications`.
    case invalidPath(String)
    /// The app is an Apple system app and must not be removed.
    case systemApp(String)
    /// `FileManager.trashItem` could not move the app to the Trash.
    case trashFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Refusing to uninstall: path is not inside /Applications or ~/Applications (\(path))."
        case .systemApp(let bundleID):
            return "Refusing to uninstall Apple system app: \(bundleID)."
        case .trashFailed(let message):
            return "Failed to move app to Trash: \(message)"
        }
    }
}

/// Moves an application bundle to the Trash, guarded by path and bundle checks.
public final class Uninstaller {
    public init() {}

    /// Moves the given app to the Trash.
    ///
    /// The operation is refused unless the app is a non-Apple app located under
    /// one of the standard applications directories.
    public func uninstallApp(_ app: InstalledApp) throws {
        let appURL = URL(fileURLWithPath: app.path)
        try validate(app)

        do {
            _ = try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
        } catch {
            throw UninstallError.trashFailed(error.localizedDescription)
        }
    }

    /// Confirms that the app is safe to remove before touching the filesystem.
    private func validate(_ app: InstalledApp) throws {
        if app.bundleID.hasPrefix("com.apple.") {
            throw UninstallError.systemApp(app.bundleID)
        }

        let appPath = URL(fileURLWithPath: app.path).standardizedFileURL.path
        let applicationsRoot = URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL.path
        let homeApplicationsRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
            .path

        let isUnderApplications = appPath == applicationsRoot || appPath.hasPrefix(applicationsRoot + "/")
        let isUnderHomeApplications = appPath == homeApplicationsRoot || appPath.hasPrefix(homeApplicationsRoot + "/")

        guard isUnderApplications || isUnderHomeApplications else {
            throw UninstallError.invalidPath(app.path)
        }
    }
}
