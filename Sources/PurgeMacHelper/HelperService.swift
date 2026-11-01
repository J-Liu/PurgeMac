// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Darwin
import Foundation
import PurgeMacCore

/// The root-side implementation of the privileged move operation.
final class HelperService: NSObject, PurgeMacHelperProtocol {

    func helperVersion(withReply reply: @escaping (String) -> Void) {
        reply(PurgeMacHelperConstants.version)
    }

    func moveToTrash(paths: [String], withReply reply: @escaping ([String]) -> Void) {
        guard let connection = NSXPCConnection.current() else {
            NSLog("PurgeMacHelper: no current XPC connection")
            reply([])
            return
        }

        let ownerUID = connection.effectiveUserIdentifier
        let ownerGID = connection.effectiveGroupIdentifier

        guard ownerUID != 0, let homeDirectory = homeDirectory(for: ownerUID) else {
            NSLog("PurgeMacHelper: invalid peer uid %u", ownerUID)
            reply([])
            return
        }

        // Require administrator
        guard isAdministrator(uid: ownerUID) else {
            NSLog("PurgeMacHelper: non-administrator uid %u refused", ownerUID)
            reply([])
            return
        }

        let trashDirectory = homeDirectory.appendingPathComponent(".Trash", isDirectory: true)
        guard let trashFD = openTrashDirectory(trashDirectory, ownerUID: ownerUID) else {
            NSLog("PurgeMacHelper: cannot open Trash directory")
            reply([])
            return
        }
        defer { close(trashFD) }

        var moved: [String] = []
        for path in paths {
            if moveItemToTrash(URL(fileURLWithPath: path), trashFD: trashFD, uid: ownerUID, gid: ownerGID) {
                moved.append(path)
            }
        }
        reply(moved)
    }

    // MARK: - Private

    private func homeDirectory(for uid: uid_t) -> URL? {
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(bufferSize))

        let path: String? = buffer.withUnsafeMutableBufferPointer { storage in
            guard let baseAddress = storage.baseAddress else { return nil }
            let status = getpwuid_r(uid, &record, baseAddress, storage.count, &result)
            guard status == 0, result != nil, let directory = record.pw_dir else { return nil }
            return String(cString: directory)
        }
        return path.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
    }

    private func isAdministrator(uid: uid_t) -> Bool {
        var record = passwd()
        var result: UnsafeMutablePointer<passwd>?
        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else { return false }
        var buffer = [CChar](repeating: 0, count: Int(bufferSize))

        let identity: (name: String, primaryGID: Int32)? = buffer.withUnsafeMutableBufferPointer { storage in
            guard let baseAddress = storage.baseAddress else { return nil }
            let status = getpwuid_r(uid, &record, baseAddress, storage.count, &result)
            guard status == 0, result != nil, let namePointer = record.pw_name else { return nil }
            return (String(cString: namePointer), Int32(record.pw_gid))
        }
        guard let identity else { return false }

        let adminGID: Int32 = 80
        var count: Int32 = 32
        var groups = [Int32](repeating: 0, count: Int(count))
        let queried = identity.name.withCString {
            getgrouplist($0, identity.primaryGID, &groups, &count)
        }
        if queried == -1 {
            groups = [Int32](repeating: 0, count: Int(count))
            _ = identity.name.withCString {
                getgrouplist($0, identity.primaryGID, &groups, &count)
            }
        }
        return groups.prefix(Int(count)).contains(adminGID)
    }

    private func openTrashDirectory(_ url: URL, ownerUID: uid_t) -> Int32? {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { return nil }

        var info = stat()
        guard fstat(fd, &info) == 0,
              (info.st_mode & S_IFMT) == S_IFDIR,
              info.st_uid == ownerUID else {
            close(fd)
            return nil
        }
        return fd
    }

    private func moveItemToTrash(_ source: URL, trashFD: Int32, uid: uid_t, gid: gid_t) -> Bool {
        // Open source parent directory
        let parent = source.deletingLastPathComponent()
        let parentFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard parentFD >= 0 else { return false }
        defer { close(parentFD) }

        let name = source.lastPathComponent

        // Find unique destination name
        var candidate = name
        var suffix = 0
        while true {
            let result = name.withCString { sourceName in
                candidate.withCString { destName in
                    renameatx_np(parentFD, sourceName, trashFD, destName, UInt32(RENAME_EXCL))
                }
            }
            if result == 0 { break }
            if errno != EEXIST { return false }

            suffix += 1
            let ext = source.pathExtension
            let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
            candidate = ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
            if suffix > 1000 { return false }
        }

        // Change ownership after move
        let movedFD = openat(trashFD, candidate, O_RDONLY | O_NOFOLLOW)
        if movedFD >= 0 {
            _ = chownRecursively(fileDescriptor: movedFD, uid: uid, gid: gid)
            close(movedFD)
        }
        return true
    }

    private func chownRecursively(fileDescriptor: Int32, uid: uid_t, gid: gid_t) -> Bool {
        var info = stat()
        guard fstat(fileDescriptor, &info) == 0 else { return false }
        var succeeded = true

        if (info.st_mode & S_IFMT) == S_IFDIR {
            let duplicate = dup(fileDescriptor)
            guard duplicate >= 0, let directory = fdopendir(duplicate) else {
                if duplicate >= 0 { close(duplicate) }
                return false
            }
            defer { closedir(directory) }

            while let entry = readdir(directory) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                    pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                        String(cString: $0)
                    }
                }
                if name == "." || name == ".." { continue }

                let childFD = name.withCString {
                    openat(fileDescriptor, $0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
                }
                if childFD >= 0 {
                    if !chownRecursively(fileDescriptor: childFD, uid: uid, gid: gid) {
                        succeeded = false
                    }
                    close(childFD)
                } else if errno == ELOOP {
                    let result = name.withCString {
                        fchownat(fileDescriptor, $0, uid, gid, AT_SYMLINK_NOFOLLOW)
                    }
                    if result != 0 { succeeded = false }
                } else {
                    succeeded = false
                }
            }
        }

        if fchown(fileDescriptor, uid, gid) != 0 { succeeded = false }
        return succeeded
    }
}