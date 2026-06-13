import Foundation

public enum UsageSource: String, Codable, Equatable, Sendable {
    case account
    case localEstimate
    case cache
}

public struct DailyUsage: Codable, Equatable, Identifiable, Sendable {
    public var id: String { date }

    public let date: String
    public let tokens: Int64
    public let source: UsageSource

    public init(date: String, tokens: Int64, source: UsageSource) {
        self.date = date
        self.tokens = tokens
        self.source = source
    }
}

public enum RateWindowKind: String, Codable, Equatable, Sendable {
    case fiveHour
    case weekly
    case unknown
}

public struct RateWindow: Codable, Equatable, Sendable {
    public let kind: RateWindowKind
    public let remainingPercent: Int
    public let usedPercent: Int
    public let resetsAt: Date?

    public init(kind: RateWindowKind, remainingPercent: Int, usedPercent: Int, resetsAt: Date?) {
        self.kind = kind
        self.remainingPercent = remainingPercent.clamped(to: 0...100)
        self.usedPercent = usedPercent.clamped(to: 0...100)
        self.resetsAt = resetsAt
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let days: [DailyUsage]
    public let fiveHour: RateWindow?
    public let weekly: RateWindow?
    public let updatedAt: Date
    public let isStale: Bool

    public init(
        days: [DailyUsage],
        fiveHour: RateWindow?,
        weekly: RateWindow?,
        updatedAt: Date,
        isStale: Bool
    ) {
        self.days = days
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.updatedAt = updatedAt
        self.isStale = isStale
    }

    public static var empty: UsageSnapshot {
        UsageSnapshot(
            days: DateCoding.lastSevenDateKeys().map {
                DailyUsage(date: $0, tokens: 0, source: .cache)
            },
            fiveHour: nil,
            weekly: nil,
            updatedAt: Date(),
            isStale: true
        )
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let primary: RateLimitWindowPayload?
    public let secondary: RateLimitWindowPayload?
    public let rateLimitReachedType: String?

    public init(
        limitId: String?,
        limitName: String?,
        primary: RateLimitWindowPayload?,
        secondary: RateLimitWindowPayload?,
        rateLimitReachedType: String?
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.rateLimitReachedType = rateLimitReachedType
    }

    public var rateWindows: (fiveHour: RateWindow?, weekly: RateWindow?) {
        let windows = [primary, secondary].compactMap { $0?.rateWindow() }
        let fiveHour = windows.first { $0.kind == .fiveHour }
        let weekly = windows.first { $0.kind == .weekly }
        return (fiveHour, weekly)
    }
}

public struct RateLimitWindowPayload: Codable, Equatable, Sendable {
    public let resetsAt: Int64?
    public let usedPercent: Int
    public let windowDurationMins: Int64?

    public init(resetsAt: Int64?, usedPercent: Int, windowDurationMins: Int64?) {
        self.resetsAt = resetsAt
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
    }

    public func rateWindow() -> RateWindow {
        let kind: RateWindowKind
        if let windowDurationMins, (240...360).contains(windowDurationMins) {
            kind = .fiveHour
        } else if let windowDurationMins, (9_000...11_000).contains(windowDurationMins) {
            kind = .weekly
        } else {
            kind = .unknown
        }

        return RateWindow(
            kind: kind,
            remainingPercent: 100 - usedPercent,
            usedPercent: usedPercent,
            resetsAt: resetsAt.map(DateCoding.dateFromFlexibleEpoch)
        )
    }
}

public extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
