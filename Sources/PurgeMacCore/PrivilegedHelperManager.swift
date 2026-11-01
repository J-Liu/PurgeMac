// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Combine
import Foundation
import ServiceManagement

/// The result of a privileged move operation.
public struct PrivilegedMoveResult {
    public let moved: [URL]
    public let failed: [URL]

    public init(moved: [URL], failed: [URL]) {
        self.moved = moved
        self.failed = failed
    }
}

/// Manages the privileged helper: registration, status, and XPC communication.
@MainActor
public final class PrivilegedHelperManager: ObservableObject {
    public static let shared = PrivilegedHelperManager()

    @Published public private(set) var isEnabled = false
    @Published public private(set) var isUnresponsive = false

    private init() {}

    // MARK: - Status

    /// Check helper status. Must be called after app launch.
    public func checkStatus() {
        let service = SMAppService.daemon(plistName: PurgeMacHelperConstants.daemonPlistName)
        isEnabled = service.status == .enabled
    }

    // MARK: - Registration

    /// Registers the helper with the system.
    /// Returns true if already enabled or successfully registered.
    public func register() -> Bool {
        let service = SMAppService.daemon(plistName: PurgeMacHelperConstants.daemonPlistName)
        do {
            try service.register()
        } catch {
            NSLog("PurgeMac: helper register() failed: \(error.localizedDescription)")
        }
        checkStatus()
        return isEnabled
    }

    /// Opens System Settings to let user enable the helper.
    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Unregisters the helper.
    public func unregister() async -> Bool {
        let service = SMAppService.daemon(plistName: PurgeMacHelperConstants.daemonPlistName)
        do {
            try await service.unregister()
            checkStatus()
            return true
        } catch {
            NSLog("PurgeMac: helper unregister() failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - XPC Communication

    /// Moves paths to Trash using the privileged helper.
    /// Returns nil if helper is not available.
    public func moveToTrash(_ urls: [URL]) async -> PrivilegedMoveResult? {
        guard isEnabled, !urls.isEmpty else { return nil }

        let connection = NSXPCConnection(
            machServiceName: PurgeMacHelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: PurgeMacHelperProtocol.self)

        // Set code signing requirement for security
        // Note: In development without proper signing, we skip this check
        // TODO: Enable in production: connection.setCodeSigningRequirement(PurgeMacHelperConstants.helperRequirement)

        connection.resume()
        defer { connection.invalidate() }

        let paths = urls.map(\.path)

        return await withCheckedContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                NSLog("PurgeMac: helper XPC error: \(error.localizedDescription)")
                continuation.resume(returning: PrivilegedMoveResult(moved: [], failed: urls))
            } as? PurgeMacHelperProtocol

            guard let proxy else {
                continuation.resume(returning: nil)
                return
            }

            proxy.moveToTrash(paths: paths) { movedPaths in
                let movedSet = Set(movedPaths)
                let moved = urls.filter { movedSet.contains($0.path) }
                let failed = urls.filter { !movedSet.contains($0.path) }
                continuation.resume(returning: PrivilegedMoveResult(moved: moved, failed: failed))
            }
        }
    }

    /// Checks if the helper is responsive and has correct version.
    public func checkResponsive() async -> Bool {
        guard isEnabled else { return false }

        let connection = NSXPCConnection(
            machServiceName: PurgeMacHelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: PurgeMacHelperProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                continuation.resume(returning: false)
            }

            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                continuation.resume(returning: false)
            } as? PurgeMacHelperProtocol

            guard let proxy else {
                continuation.resume(returning: false)
                return
            }

            proxy.helperVersion { version in
                continuation.resume(returning: version == PurgeMacHelperConstants.version)
            }
        }
    }
}