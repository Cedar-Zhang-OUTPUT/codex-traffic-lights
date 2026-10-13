import SwiftUI
import LightCore

@MainActor
final class LightModel: ObservableObject {
    @Published var state: LampState = .idle
    @Published var count = 0
    @Published var readFailed = false

    var title: String {
        if readFailed { return "状态读取失败" }
        switch state {
        case .idle: return "Codex 空闲"
        case .running: return "Codex 正在运行"
        case .attention: return "Codex 需要你处理"
        }
    }
}

struct LightView: View {
    static let width: CGFloat = 76
    static let height: CGFloat = 164
    @ObservedObject var model: LightModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func lens(_ state: LampState, color: Color, intensity: Double) -> some View {
        let active = model.state == state
        return Circle()
            .fill(.primary.opacity(0.12))
            .overlay {
                Circle().fill(color.gradient).opacity(active ? intensity : 0.13)
            }
            .overlay { Circle().strokeBorder(.primary.opacity(0.07), lineWidth: 0.5) }
            .frame(width: 26, height: 26)
            .shadow(color: color.opacity(active ? intensity * 0.5 : 0), radius: 7)
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(active ? 0.55 * intensity : 0.10))
                    .frame(width: 7, height: 4).rotationEffect(.degrees(-35))
                    .offset(x: 6, y: 5)
            }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: model.state != .running || reduceMotion)) { timeline in
            let breathing = model.state == .running && !reduceMotion
            let wave = (sin(timeline.date.timeIntervalSinceReferenceDate * .pi / 1.3) + 1) / 2
            let intensity = breathing ? 0.42 + wave * 0.58 : 1
            VStack(spacing: 14) {
                lens(.idle, color: Color(red: 0.16, green: 0.85, blue: 0.44), intensity: 1)
                lens(.running, color: Color(red: 1, green: 0.73, blue: 0.12), intensity: intensity)
                lens(.attention, color: Color(red: 1, green: 0.24, blue: 0.26), intensity: 1)
            }
            .padding(16)
            .glassEffect(.regular, in: Capsule())
            .frame(width: Self.width, height: Self.height)
            .animation(.easeInOut(duration: 0.2), value: model.state)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.title)
        .help(model.title + " · 拖动可移动，右键打开菜单")
    }
}
