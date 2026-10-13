import AppKit
import SwiftUI
import LightCore

final class LightPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class DragView: NSHostingView<LightView> {
    var menuProvider: (() -> NSMenu)?
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = LightModel()
    let store = SessionStore()
    private var panel: LightPanel!
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only one indicator instance may own the state reset.
        if NSRunningApplication.runningApplications(withBundleIdentifier: "local.cedar.CodexLight").count > 1 {
            NSApp.terminate(nil); return
        }
        try? store.clear()
        panel = LightPanel(contentRect: NSRect(x: 0, y: 0, width: LightView.width, height: LightView.height),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Codex Light"
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        let view = DragView(rootView: LightView(model: model))
        view.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        panel.contentView = view
        positionPanel()
        panel.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer?.tolerance = 0.15
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "lampX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "lampY")
    }

    private func positionPanel() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        var origin = NSPoint(x: visible.maxX - 100, y: visible.maxY - LightView.height - 24)
        if UserDefaults.standard.object(forKey: "lampX") != nil {
            let candidate = NSRect(x: UserDefaults.standard.double(forKey: "lampX"),
                                   y: UserDefaults.standard.double(forKey: "lampY"), width: LightView.width, height: LightView.height)
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(candidate) }) { origin = candidate.origin }
        }
        panel.setFrameOrigin(origin)
    }

    private func refresh() {
        do {
            try store.reapExitedOwners()
            let records = try store.records()
            model.count = records.count
            model.readFailed = false
            model.state = LampState.aggregate(records.map(\.state))
        } catch SessionStore.Failure.busy {
            return // A brief write in progress is not a Codex problem.
        } catch {
            model.readFailed = true
            model.state = .attention
        }
        let color: NSColor = model.state == .attention ? .systemRed : (model.state == .running ? .systemYellow : .systemGreen)
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 10, height: 10)).fill()
            return true
        }
        statusItem.button?.image = icon
        statusItem.button?.toolTip = model.title
        panel.setAccessibilityLabel(model.title)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: model.title, action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "\(model.count) 个会话 · 红 > 黄 > 绿", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let install = menu.addItem(withTitle: "安装／更新 Codex Hooks…", action: #selector(installHooks), keyEquivalent: "")
        install.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 Codex Light", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        return menu
    }

    @objc private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func installHooks() {
        let alert = NSAlert()
        do {
            try installLightHooks()
            alert.messageText = "Hooks 已安装"
            alert.informativeText = "请在 Codex 新对话顶部检查并信任 Hooks，已打开的客户端可能需要重启。"
        } catch {
            alert.messageText = "Hooks 安装失败"
            alert.informativeText = error.localizedDescription
        }
        alert.runModal()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
