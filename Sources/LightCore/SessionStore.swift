import Foundation
import CryptoKit
import Darwin

public struct SessionStore: Sendable {
    public enum Failure: Error { case busy }
    public let root: URL
    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Codex Light/sessions")) {
        self.root = root
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        let fd = open(root.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.2
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN else { throw CocoaError(.fileWriteUnknown) }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure.busy }
            usleep(5_000)
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    public func apply(_ event: [String: Any], owner: Int32? = nil) throws {
        guard let id = event["session_id"] as? String, !id.isEmpty,
              let name = event["hook_event_name"] as? String,
              HookConfiguration.events.contains(name) else { return }
        try locked {
            let hash = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
            let file = root.appendingPathComponent(hash + ".json")
            if name == "SessionEnd" {
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                return
            }
            var record = (try? JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: file))) ?? SessionRecord()
            record.apply(event)
            if let owner { record.owner = owner }
            record.updatedAt = Date()
            try JSONEncoder().encode(record).write(to: file, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }

    public func records() throws -> [SessionRecord] {
        try locked {
            let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }.compactMap {
                try? JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: $0))
            }
        }
    }

    public func reapExitedOwners() throws {
        try locked {
            for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let record = try? JSONDecoder().decode(SessionRecord.self, from: data),
                      let pid = record.owner, kill(pid, 0) != 0, errno == ESRCH else { continue }
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    public func clear() throws {
        try locked {
            for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                where file.pathExtension == "json" { try FileManager.default.removeItem(at: file) }
        }
    }
}
