import Foundation

public enum DateCoding {
    private static func isoFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func isoFormatterNoFractional() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    public static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    public static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }

    public static func parseISODate(_ value: String) -> Date? {
        isoFormatter().date(from: value) ?? isoFormatterNoFractional().date(from: value)
    }

    public static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    public static func lastSevenDateKeys(now: Date = Date(), calendar: Calendar = .current) -> [String] {
        (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map(dayKey)
        }
    }

    public static func dateFromFlexibleEpoch(_ value: Int64) -> Date {
        if value > 10_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
        }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }
}
