import Foundation
import Testing
import Darwin
@testable import LightCore

@Test func priorityAcrossSessions() {
    #expect(LampState.aggregate([]) == .idle)
    #expect(LampState.aggregate([.idle, .running]) == .running)
    #expect(LampState.aggregate([.running, .attention, .idle]) == .attention)
}

private func event(_ name: String, tool: String = "Bash", id: String = "tool-1", response: Any = [:]) -> [String: Any] {
    ["session_id": "a", "hook_event_name": name, "tool_name": tool, "tool_use_id": id, "tool_response": response]
}

@Test func anotherToolCannotClearPendingQuestion() {
    var state = SessionRecord()
    state.apply(event("PreToolUse", tool: "request_user_input"))
    state.apply(event("PostToolUse", id: "tool-2"))
    #expect(state.state == .attention)
    state.apply(event("PostToolUse"))
    #expect(state.state == .running)
    state.apply(event("Stop"))
    #expect(state.state == .idle)
}

@Test func explicitFailurePersistsUntilRecovery() {
    var state = SessionRecord()
    state.apply(event("PostToolUse", response: ["exit_code": 2]))
    #expect(state.state == .attention)
    state.apply(event("Stop"))
    #expect(state.state == .attention)
    state.apply(event("UserPromptSubmit"))
    #expect(state.state == .running)
    state.apply(event("PostToolUse", response: ["output": "error: example text, not a status"]))
    #expect(state.state == .running)
}

@Test func malformedConfigurationIsRejectedAndOthersArePreserved() throws {
    let original: [String: Any] = ["custom": true, "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo existing"]]]]]]
    let data = try JSONSerialization.data(withJSONObject: original)
    let merged = try HookConfiguration.merging(data, executable: "/Applications/Codex Light.app/Contents/MacOS/CodexLight")
    let twice = try HookConfiguration.merging(merged, executable: "/Applications/Codex Light.app/Contents/MacOS/CodexLight")
    let json = try #require(JSONSerialization.jsonObject(with: twice) as? [String: Any])
    #expect(json["custom"] as? Bool == true)
    let hooks = try #require(json["hooks"] as? [String: Any])
    #expect((hooks["Stop"] as? [Any])?.count == 2)
    #expect(throws: (any Error).self) { try HookConfiguration.merging(Data("broken".utf8), executable: "/app") }
    #expect(throws: (any Error).self) { try HookConfiguration.merging(Data("{\"hooks\":[]}".utf8), executable: "/app") }
}

@Test func independentSessionsAndExplicitEnd() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(root: root)
    try store.apply(event("UserPromptSubmit"))
    var second = event("PermissionRequest")
    second["session_id"] = "b/../../untrusted"
    try store.apply(second)
    #expect(try store.records().count == 2)
    #expect(LampState.aggregate(try store.records().map(\.state)) == .attention)
    second["hook_event_name"] = "SessionEnd"
    try store.apply(second)
    #expect(LampState.aggregate(try store.records().map(\.state)) == .running)
    try store.apply(event("Stop"))
    #expect(LampState.aggregate(try store.records().map(\.state)) == .idle)
}

@Test func emptyErrorFieldIsNotAnError() {
    for error: Any in ["", false, NSNull()] {
        var record = SessionRecord()
        record.apply(event("PostToolUse", response: ["error": error, "exit_code": 0]))
        #expect(record.state == .running)
    }
}

@Test func asyncQuestionStaysRedUntilUserReplies() {
    var record = SessionRecord()
    record.apply(event("PreToolUse", tool: "functions.request_user_input_async"))
    record.apply(event("PostToolUse", tool: "functions.request_user_input_async"))
    record.apply(event("Stop"))
    #expect(record.state == .attention)
    record.apply(event("UserPromptSubmit"))
    #expect(record.state == .running)
}

@Test func parallelWritesDoNotLoseSessions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(root: root)
    DispatchQueue.concurrentPerform(iterations: 20) { index in
        try! store.apply(["session_id": "session-\(index)", "hook_event_name": "UserPromptSubmit"])
    }
    #expect(try store.records().count == 20)
    try Data("partial".utf8).write(to: root.appendingPathComponent("corrupt.json"))
    #expect(try store.records().count == 20)
}

@Test func installerBacksUpAndDoesNotClobberInvalidJSON() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let file = home.appendingPathComponent("hooks.json")
    let original = Data("{\"custom\":42}".utf8)
    try original.write(to: file)
    try HookConfiguration.install(executable: "/tmp/a'b/CodexLight", codexHome: home)
    let backup = try #require(FileManager.default.contentsOfDirectory(at: home, includingPropertiesForKeys: nil)
        .first { $0.lastPathComponent.hasPrefix("hooks.before-") })
    #expect(try Data(contentsOf: backup) == original)
    let invalid = Data("invalid JSON".utf8)
    try invalid.write(to: file)
    #expect(throws: (any Error).self) { try HookConfiguration.install(executable: "/app", codexHome: home) }
    #expect(try Data(contentsOf: file) == invalid)
}

@Test func documentedPermissionWithoutToolIDResolvesAfterItsTool() {
    var record = SessionRecord()
    let pending: [String: Any] = ["hook_event_name": "PermissionRequest", "tool_name": "Bash",
                                  "tool_input": ["command": "echo approved"]]
    record.apply(pending)
    var unrelated = event("PostToolUse", id: "different")
    unrelated["tool_input"] = ["command": "echo unrelated"]
    record.apply(unrelated)
    #expect(record.state == .attention)
    var finished = event("PostToolUse")
    finished["tool_input"] = ["command": "echo approved"]
    record.apply(finished)
    #expect(record.state == .running)
    record.apply(event("Stop"))
    #expect(record.state == .idle)
}

@Test func compactionSessionStartKeepsRunningAndPendingWaits() {
    var record = SessionRecord()
    record.apply(event("UserPromptSubmit"))
    record.apply(["hook_event_name": "SessionStart", "source": "compact"])
    #expect(record.state == .running)
    record.apply(event("PermissionRequest"))
    record.apply(["hook_event_name": "SessionStart", "source": "compact"])
    #expect(record.state == .attention)
}

@Test func busyStoreDoesNotBlockHookIndefinitely() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let fd = open(root.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
    defer { close(fd) }
    #expect(flock(fd, LOCK_EX) == 0)
    defer { flock(fd, LOCK_UN) }
    let store = SessionStore(root: root)
    let done = DispatchGroup()
    done.enter()
    DispatchQueue.global().async {
        defer { done.leave() }
        try? store.apply(["session_id": "a", "hook_event_name": "UserPromptSubmit"])
    }
    let finishedWhileLocked = done.wait(timeout: .now() + 0.75) == .success
    flock(fd, LOCK_UN)
    done.wait()
    #expect(finishedWhileLocked)
}

@Test func manualCompactionReturnsToPreviousIdle() {
    var record = SessionRecord()
    record.apply(["hook_event_name": "PreCompact", "trigger": "manual"])
    #expect(record.state == .running)
    record.apply(["hook_event_name": "PostCompact", "trigger": "manual"])
    #expect(record.state == .idle)
    record.apply(["hook_event_name": "SessionStart", "source": "compact"])
    #expect(record.state == .idle)
}
