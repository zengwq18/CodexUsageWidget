import CodexUsageCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 8) {
            header
            HeatmapView(days: viewModel.snapshot.days)
            VStack(spacing: 5) {
                QuotaRow(title: "5 小时", window: viewModel.snapshot.fiveHour)
                QuotaRow(title: "本周", window: viewModel.snapshot.weekly)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 280, height: 132)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Codex")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Circle()
                .fill(viewModel.snapshot.isStale ? Color.orange : Color.green)
                .frame(width: 6, height: 6)

            Text(viewModel.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            IconButton(systemName: viewModel.pinned ? "pin.fill" : "pin") {
                viewModel.pinned.toggle()
            }
            .help(viewModel.pinned ? "取消置顶" : "置顶")

            IconButton(systemName: "arrow.clockwise") {
                viewModel.refresh()
            }
            .rotationEffect(.degrees(viewModel.isRefreshing ? 180 : 0))
            .animation(.easeInOut(duration: 0.25), value: viewModel.isRefreshing)
            .help("刷新")

            IconButton(systemName: "gearshape") {
                showsSettings.toggle()
            }
            .popover(isPresented: $showsSettings, arrowEdge: .top) {
                SettingsView(viewModel: viewModel)
                    .frame(width: 220)
                    .padding(14)
            }
            .help("设置")
        }
        .foregroundStyle(.primary)
    }
}

private struct HeatmapView: View {
    let days: [DailyUsage]

    private var peak: Int64 {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color(for: day.tokens))
                        .frame(width: 27, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .help(tooltip(for: day))

                    Text(weekday(for: day.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 29)
            }
        }
        .frame(height: 37)
    }

    private func color(for tokens: Int64) -> Color {
        guard tokens > 0 else { return Color(nsColor: .quaternaryLabelColor).opacity(0.35) }
        let ratio = Double(tokens) / Double(peak)
        switch ratio {
        case ..<0.25:
            return Color(red: 0.22, green: 0.68, blue: 0.40)
        case ..<0.50:
            return Color(red: 0.10, green: 0.62, blue: 0.68)
        case ..<0.75:
            return Color(red: 0.90, green: 0.60, blue: 0.18)
        case ..<1.0:
            return Color(red: 0.86, green: 0.30, blue: 0.22)
        default:
            return Color(red: 0.58, green: 0.18, blue: 0.58)
        }
    }

    private func tooltip(for day: DailyUsage) -> String {
        let ratio = Int((Double(day.tokens) / Double(peak) * 100).rounded())
        let source = day.source == .account ? "账户用量" : day.source == .localEstimate ? "本地估算" : "缓存"
        return "\(day.date)\n\(Formatters.fullTokenCount(day.tokens)) tokens\n最近 7 天峰值的 \(ratio)%\n\(source)"
    }

    private func weekday(for dateKey: String) -> String {
        guard let date = DateCoding.dayFormatter.date(from: dateKey) else {
            return String(dateKey.suffix(2))
        }

        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let index = Calendar.current.component(.weekday, from: date) - 1
        return symbols[index.clamped(to: 0...6)]
    }
}

private struct QuotaRow: View {
    let title: String
    let window: RateWindow?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 38, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)

            Text(detailText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(height: 15)
        .help(helpText)
    }

    private var progress: CGFloat {
        CGFloat(Double(window?.remainingPercent ?? 0) / 100.0)
    }

    private var fillColor: Color {
        guard let window else { return .secondary.opacity(0.25) }
        switch window.remainingPercent {
        case 50...100:
            return Color(red: 0.17, green: 0.62, blue: 0.42)
        case 20..<50:
            return Color(red: 0.90, green: 0.60, blue: 0.18)
        default:
            return Color(red: 0.86, green: 0.30, blue: 0.22)
        }
    }

    private var detailText: String {
        guard let window else { return "等待连接" }
        return "\(window.remainingPercent)%"
    }

    private var helpText: String {
        guard let window else { return "\(title)额度：等待 Codex 登录或连接" }
        let reset = window.resetsAt.map { DateCoding.timeFormatter.string(from: $0) } ?? "未知"
        return "\(title)剩余 \(window.remainingPercent)%\n已用 \(window.usedPercent)%\n刷新 \(reset)"
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
