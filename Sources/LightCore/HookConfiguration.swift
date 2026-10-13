import Foundation

public enum HookConfiguration {
    public static let events = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse",
                               "PermissionRequest", "PostToolUse", "PreCompact", "PostCompact", "Stop", "Interrupt"]
    private static let marker = "--codex-light-hook"

    public static func merging(_ data: Data?, executable: String) throws -> Data {
        var root: [String: Any] = [:]
        if let data {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            root = parsed
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) { throw CocoaError(.fileReadCorruptFile) }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        for event in events {
            if let entries = hooks[event], !(entries is [[String: Any]]) { throw CocoaError(.fileReadCorruptFile) }
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries = entries.compactMap { entry in
                var entry = entry
                guard let handlers = entry["hooks"] as? [[String: Any]] else { return entry }
                let retained = handlers.filter { !(($0["command"] as? String)?.contains(marker) ?? false) }
                if retained.isEmpty && !handlers.isEmpty { return nil }
                entry["hooks"] = retained
                return entry
            }
            entries.append(["matcher": "", "hooks": [["type": "command", "command": quoted + " " + marker, "timeout": 3]]])
            hooks[event] = entries
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func install(executable: String, codexHome: URL) throws {
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let file = codexHome.appendingPathComponent("hooks.json")
        let original = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        let merged = try merging(original, executable: executable)
        if let original, original != merged {
            let backup = codexHome.appendingPathComponent("hooks.before-codex-light-\(UUID().uuidString).json")
            try original.write(to: backup, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try merged.write(to: file, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
