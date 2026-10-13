import Foundation
import AppKit
import Darwin
import LightCore

func codexOwner() -> Int32? {
    var pid = getppid()
    for _ in 0..<20 {
        guard pid > 1 else { return nil }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        if proc_pidpath(pid, &path, UInt32(path.count)) > 0 {
            let name = URL(fileURLWithPath: String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)).lastPathComponent
            if name == "codex" { return pid }
        }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        pid = Int32(info.pbi_ppid)
    }
    return nil
}

func codexHome() -> URL {
    if let path = ProcessInfo.processInfo.environment["CODEX_HOME"], !path.isEmpty {
        return URL(fileURLWithPath: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
}

func installLightHooks() throws {
    // Keep the helper outside the .app, so trashing the UI cannot break cached Hooks.
    let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Codex Light/bin")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                          attributes: [.posixPermissions: 0o700])
    let helper = directory.appendingPathComponent("CodexLightHook")
    let binary = try Data(contentsOf: Bundle.main.executableURL!)
    try binary.write(to: helper, options: [.atomic])
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    try HookConfiguration.install(executable: helper.path, codexHome: codexHome())
}

if CommandLine.arguments.contains("--codex-light-hook") {
    // Every path returns success, including malformed input or an unavailable store.
    // A status indicator must never interfere with the conversation it observes.
    if let event = try? JSONSerialization.jsonObject(with: FileHandle.standardInput.readDataToEndOfFile()) as? [String: Any] {
        try? SessionStore().apply(event, owner: codexOwner())
    }
    print("{}")
} else if CommandLine.arguments.contains("--install-hooks") {
    do {
        try installLightHooks()
        print("Codex Hooks 已安装，请在 Codex 新对话中检查并信任。")
    } catch {
        FileHandle.standardError.write(Data("安装失败，未覆盖现有配置：\(error.localizedDescription)\n".utf8))
        exit(1)
    }
} else {
    let app = NSApplication.shared
    let controller = AppController()
    app.delegate = controller
    app.setActivationPolicy(.accessory)
    app.run()
}
