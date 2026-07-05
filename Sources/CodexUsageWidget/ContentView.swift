import CodexUsageCore
import SwiftUI

enum UsageSurface {
    case floatingPanel
    case menuBar
}

enum UsageWidgetLayout {
    static let width: CGFloat = 280
    static let expandedHeight: CGFloat = 206
    static let compactHeight: CGFloat = 116
}

struct ContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    var surface: UsageSurface = .floatingPanel
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 8) {
            header
            if viewModel.showsSevenDayUsage {
                UsageBarChartView(days: viewModel.snapshot.days)
                    .padding(.top, 6)
            }
            VStack(spacing: 5) {
                QuotaRow(title: "5 小时", window: viewModel.snapshot.fiveHour)
                QuotaRow(title: "本周", window: viewModel.snapshot.weekly)
                ResetCreditsRow(summary: viewModel.snapshot.resetCredits)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(
            width: UsageWidgetLayout.width,
            height: viewModel.showsSevenDayUsage ? UsageWidgetLayout.expandedHeight : UsageWidgetLayout.compactHeight
        )
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

            if surface == .floatingPanel {
                IconButton(systemName: viewModel.pinned ? "pin.fill" : "pin") {
                    viewModel.pinned.toggle()
                }
                .help(viewModel.pinned ? "取消置顶" : "置顶")
            }

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
                SettingsView(
                    viewModel: viewModel,
                    showsPinnedToggle: surface == .floatingPanel
                )
                    .frame(width: 220)
                    .padding(14)
            }
            .help("设置")
        }
        .foregroundStyle(.primary)
    }
}

private struct ResetCreditsRow: View {
    let summary: RateLimitResetCreditsSummary?
    @State private var showsDetails = false

    var body: some View {
        Button {
            guard summary != nil else { return }
            showsDetails.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Text("可用重置")
                    .font(.system(size: 10, weight: .semibold))

                Spacer(minLength: 4)

                Text(summaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 21, maxHeight: 21)
            .background(Color.secondary.opacity(0.11), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(summary == nil)
        .popover(isPresented: $showsDetails, arrowEdge: .bottom) {
            ResetCreditsDetailsView(summary: summary)
                .frame(width: 210)
                .padding(12)
        }
        .help(helpText)
    }

    private var summaryText: String {
        guard let summary else { return "等待数据" }
        guard summary.availableCount > 0 else { return "0 次" }
        guard let nearestExpiration = summary.nearestExpiration else {
            return "\(summary.availableCount) 次 · 过期未知"
        }
        return "\(summary.availableCount) 次 · \(Formatters.resetCreditExpirationText(for: nearestExpiration))"
    }

    private var helpText: String {
        guard let summary else { return "等待 Codex 返回重置机会" }
        guard summary.availableCount > 0 else { return "当前没有可用的重置机会" }
        if summary.expirationDates.isEmpty {
            return "可用重置 \(summary.availableCount) 次\n未返回过期时间"
        }
        let expirations = summary.expirationDates.enumerated()
            .map { index, date in "#\(index + 1) \(Formatters.resetCreditExpirationText(for: date))" }
            .joined(separator: "\n")
        return "可用重置 \(summary.availableCount) 次\n\(expirations)"
    }
}

private struct ResetCreditsDetailsView: View {
    let summary: RateLimitResetCreditsSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("过期时间")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(countText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Divider()

            if let summary, !summary.expirationDates.isEmpty {
                ForEach(Array(summary.expirationDates.enumerated()), id: \.offset) { index, date in
                    HStack(spacing: 8) {
                        Text("第 \(index + 1) 次")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Formatters.resetCreditExpirationText(for: date))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))
                }

                if summary.expirationDates.count < summary.availableCount {
                    Text("另有 \(summary.availableCount - summary.expirationDates.count) 次过期时间未知")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(emptyText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countText: String {
        guard let summary else { return "等待" }
        return "\(summary.availableCount) 次"
    }

    private var emptyText: String {
        guard let summary else {
            return "等待 Codex 返回重置机会。"
        }

        if summary.availableCount == 0 {
            return "当前没有可用的重置机会。"
        }

        return "当前 Codex 接口只返回可用次数，暂未返回各次过期时间。"
    }
}

private struct UsageBarChartView: View {
    let days: [DailyUsage]
    @State private var hoveredDay: DailyUsage?

    private let maxBarHeight: CGFloat = 38

    private var peak: Int64 {
        max(days.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(days) { day in
                            dayBar(for: day)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(width: 240, height: 1)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 5) {
                    ForEach(days) { day in
                        Text(weekday(for: day.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                            .contentShape(Rectangle())
                            .onHover { isHovering in
                                updateHover(isHovering, day: day)
                            }
                            .help(tooltip(for: day))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Text(hoverDetailText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 12, alignment: .center)
                .opacity(hoveredDay == nil ? 0 : 1)
        }
        .frame(height: 79)
    }

    private func dayBar(for day: DailyUsage) -> some View {
        VStack(spacing: 3) {
            Text(day.tokens > 0 ? Formatters.compactTokenCount(day.tokens) : " ")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 30, height: 10)

            ZStack(alignment: .bottom) {
                if day.tokens > 0 {
                    Rectangle()
                        .fill(color(for: day.tokens))
                        .frame(width: 14, height: barHeight(for: day.tokens))
                        .overlay(
                            Rectangle()
                                .stroke(strokeColor(for: day), lineWidth: hoveredDay?.id == day.id ? 1.2 : 0)
                        )
                }
            }
            .frame(width: 30, height: maxBarHeight, alignment: .bottom)
        }
        .frame(width: 30)
        .contentShape(Rectangle())
        .onHover { isHovering in
            updateHover(isHovering, day: day)
        }
        .help(tooltip(for: day))
    }

    private func updateHover(_ isHovering: Bool, day: DailyUsage) {
        if isHovering {
            hoveredDay = day
        } else if hoveredDay?.id == day.id {
            hoveredDay = nil
        }
    }

    private func color(for tokens: Int64) -> Color {
        guard tokens > 0 else {
            return Color(nsColor: .quaternaryLabelColor).opacity(0.35)
        }

        let ratio = min(max(Double(tokens) / Double(peak), 0), 1)
        let start = (red: 0.79, green: 0.90, blue: 1.00)
        let end = (red: 0.16, green: 0.58, blue: 0.96)

        return Color(
            red: start.red + (end.red - start.red) * ratio,
            green: start.green + (end.green - start.green) * ratio,
            blue: start.blue + (end.blue - start.blue) * ratio
        )
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        guard tokens > 0 else { return 0 }
        let ratio = min(max(Double(tokens) / Double(peak), 0), 1)
        return max(4, maxBarHeight * CGFloat(ratio))
    }

    private func strokeColor(for day: DailyUsage) -> Color {
        if hoveredDay?.id == day.id {
            return .primary.opacity(0.55)
        }

        return Color.black.opacity(0.08)
    }

    private var hoverDetailText: String {
        guard let hoveredDay else { return " " }
        return "\(displayDate(for: hoveredDay.date)) \(Formatters.fullTokenCount(hoveredDay.tokens)) tokens"
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

    private func displayDate(for dateKey: String) -> String {
        guard let date = DateCoding.dayFormatter.date(from: dateKey) else {
            return dateKey
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

private struct QuotaRow: View {
    let title: String
    let window: RateWindow?

    var body: some View {
        HStack(spacing: 7) {
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

            Text(percentText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
                .lineLimit(1)

            Text(resetText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 45, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(height: 15)
        .help(helpText)
    }

    private var progress: CGFloat {
        CGFloat(Double(window?.remainingPercent ?? 0) / 100.0)
    }

    private var fillColor: Color {
        guard let window else { return .secondary.opacity(0.25) }
        let ratio = Double(window.remainingPercent) / 100.0
        let start = (red: 0.58, green: 0.78, blue: 0.98)
        let end = (red: 0.20, green: 0.58, blue: 0.96)

        return Color(
            red: start.red + (end.red - start.red) * ratio,
            green: start.green + (end.green - start.green) * ratio,
            blue: start.blue + (end.blue - start.blue) * ratio
        )
    }

    private var percentText: String {
        guard let window else { return "--%" }
        return "\(window.remainingPercent)%"
    }

    private var resetText: String {
        guard let window else { return "等待" }
        return Formatters.quotaResetText(for: window) ?? "--:--"
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
