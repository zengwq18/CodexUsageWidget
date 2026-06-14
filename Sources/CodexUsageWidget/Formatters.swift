import CodexUsageCore
import Foundation

enum Formatters {
    private static let quotaResetTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let quotaResetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static func fullTokenCount(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func compactTokenCount(_ value: Int64) -> String {
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    static func quotaResetText(for window: RateWindow) -> String? {
        guard let resetsAt = window.resetsAt else { return nil }

        switch window.kind {
        case .fiveHour:
            return quotaResetTimeFormatter.string(from: resetsAt)
        case .weekly:
            return quotaResetDateFormatter.string(from: resetsAt)
        case .unknown:
            return DateCoding.timeFormatter.string(from: resetsAt)
        }
    }
}
