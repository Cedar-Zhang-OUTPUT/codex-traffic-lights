import Foundation
import CryptoKit

public enum LampState: String, Codable, Sendable {
    case idle, running, attention

    public static func aggregate(_ states: [LampState]) -> LampState {
        if states.contains(.attention) { return .attention }
        return states.contains(.running) ? .running : .idle
    }
}

public struct SessionRecord: Codable, Sendable {
    public var running = false
    public var failed = false
    public var waiting: Set<String> = []
    public var permissionWaits: [String: Int] = [:]
    public var compacting = false
    public var owner: Int32?
    public var updatedAt = Date()

    public init() {}
    public var state: LampState {
        failed || !waiting.isEmpty || !permissionWaits.isEmpty ? .attention : (running || compacting ? .running : .idle)
    }

    public mutating func apply(_ event: [String: Any]) {
        let name = event["hook_event_name"] as? String ?? ""
        let tool = event["tool_name"] as? String ?? ""
        let id = event["tool_use_id"] as? String ?? "unidentified"
        let asks = tool == "request_user_input" || tool.hasSuffix("__request_user_input")
            || tool.hasSuffix(".request_user_input") || tool == "request_user_input_async"
            || tool.hasSuffix(".request_user_input_async")
        switch name {
        case "SessionStart":
            if event["source"] as? String == "compact" { return }
            running = false; failed = false; waiting.removeAll()
            permissionWaits.removeAll(); compacting = false
        case "UserPromptSubmit":
            running = true; failed = false; waiting.removeAll()
            permissionWaits.removeAll(); compacting = false
        case "PermissionRequest":
            running = true
            if event["tool_use_id"] as? String != nil { waiting.insert(id) }
            else { permissionWaits[Self.permissionKey(event), default: 0] += 1 }
        case "PreToolUse":
            running = true; failed = false
            if asks { waiting.insert(id) }
        case "PostToolUse":
            running = true
            if !tool.hasSuffix("request_user_input_async") { waiting.remove(id) }
            let key = Self.permissionKey(event)
            if let count = permissionWaits[key] {
                if count <= 1 { permissionWaits.removeValue(forKey: key) }
                else { permissionWaits[key] = count - 1 }
            }
            if Self.explicitFailure(event["tool_response"]) { failed = true }
        case "PreCompact": compacting = true
        case "PostCompact": compacting = false
        case "Stop":
            running = false; compacting = false
        case "Interrupt", "SessionEnd":
            running = false; failed = false; waiting.removeAll()
            permissionWaits.removeAll(); compacting = false
        default: break
        }
    }

    private static func permissionKey(_ event: [String: Any]) -> String {
        let tool = event["tool_name"] as? String ?? ""
        var input = event["tool_input"] ?? NSNull()
        if (tool == "Bash" || tool == "apply_patch"), var object = input as? [String: Any] {
            object.removeValue(forKey: "description")
            input = object
        }
        let payload: [String: Any] = ["tool": tool, "turn": event["turn_id"] ?? "", "input": input]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data(tool.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func explicitFailure(_ response: Any?) -> Bool {
        var value = response
        if let text = response as? String, let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) { value = parsed }
        guard let object = value as? [String: Any] else { return false }
        if object["isError"] as? Bool == true || object["is_error"] as? Bool == true
            || object["success"] as? Bool == false { return true }
        for key in ["exit_code", "exitCode"] {
            if let number = object[key] as? Int, number != 0 { return true }
        }
        if let error = object["error"] {
            if let text = error as? String { return !text.isEmpty }
            if let flag = error as? Bool { return flag }
            if !(error is NSNull) { return true }
        }
        return false
    }
}
