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
    static let width: CGFloat = 86
    static let height: CGFloat = 188
    @ObservedObject var model: LightModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func lens(_ state: LampState, color: Color, intensity: Double) -> some View {
        let active = model.state == state
        return Circle()
            .fill(Color(red: 0.025, green: 0.035, blue: 0.05))
            .overlay {
                Circle().fill(color.gradient).opacity(active ? intensity : 0.09)
            }
            .overlay {
                Circle().strokeBorder(active ? color.opacity(0.9) : .white.opacity(0.10), lineWidth: 1)
            }
            .frame(width: 34, height: 34)
            .shadow(color: color.opacity(active ? intensity * 0.7 : 0), radius: active ? 10 * intensity : 0)
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(active ? 0.55 * intensity : 0.04))
                    .frame(width: 9, height: 5).rotationEffect(.degrees(-35))
                    .offset(x: 7, y: 6)
            }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: model.state != .running || reduceMotion)) { timeline in
            let breathing = model.state == .running && !reduceMotion
            let wave = (sin(timeline.date.timeIntervalSinceReferenceDate * .pi / 1.3) + 1) / 2
            let intensity = breathing ? 0.78 + wave * 0.22 : 1
            VStack(spacing: 14) {
                lens(.idle, color: Color(red: 0.18, green: 1, blue: 0.45), intensity: 1)
                lens(.running, color: Color(red: 1, green: 0.8, blue: 0.08), intensity: intensity)
                lens(.attention, color: Color(red: 1, green: 0.2, blue: 0.24), intensity: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(red: 0.065, green: 0.075, blue: 0.095))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            }
            .frame(width: Self.width, height: Self.height)
            .animation(.easeInOut(duration: 0.2), value: model.state)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.title)
        .help(model.title + " · 拖动可移动，右键打开菜单")
    }
}
