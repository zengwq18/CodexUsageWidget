import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case refreshInterval
    }

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

            Toggle("显示 7 日用量", isOn: $viewModel.showsSevenDayUsage)

            HStack(spacing: 8) {
                Text("每")

                TextField(
                    "",
                    value: Binding(
                        get: { viewModel.refreshIntervalValue },
                        set: { viewModel.setRefreshIntervalValue($0) }
                    ),
                    formatter: DateCodingBridge.integerFormatter
                )
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .refreshInterval)
                .frame(width: 52)

                Picker(
                    "",
                    selection: Binding(
                        get: { viewModel.refreshIntervalUnit },
                        set: { viewModel.setRefreshIntervalUnit($0) }
                    )
                ) {
                    ForEach(RefreshIntervalUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 74)

                Text("刷新")
            }

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
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }
}

private enum DateCodingBridge {
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        formatter.maximum = 1_440
        formatter.numberStyle = .none
        return formatter
    }()

    static func updatedText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
