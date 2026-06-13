import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "开机启动",
                isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                )
            )

            Toggle("置顶显示", isOn: $viewModel.pinned)

            Stepper(
                "每 \(viewModel.refreshIntervalMinutes) 分钟刷新",
                value: $viewModel.refreshIntervalMinutes,
                in: 1...60
            )

            Divider()

            HStack {
                Text("更新于")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DateCodingBridge.updatedText(viewModel.snapshot.updatedAt))
            }
            .font(.system(size: 11))

            Button("退出 Codex 用量浮窗") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .font(.system(size: 12))
    }
}

private enum DateCodingBridge {
    static func updatedText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
