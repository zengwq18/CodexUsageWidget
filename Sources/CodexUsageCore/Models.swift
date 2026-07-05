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
    public let resetCredits: RateLimitResetCreditsSummary?
    public let updatedAt: Date
    public let isStale: Bool

    public init(
        days: [DailyUsage],
        fiveHour: RateWindow?,
        weekly: RateWindow?,
        resetCredits: RateLimitResetCreditsSummary? = nil,
        updatedAt: Date,
        isStale: Bool
    ) {
        self.days = days
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.resetCredits = resetCredits
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
            resetCredits: nil,
            updatedAt: Date(),
            isStale: true
        )
    }
}

public struct RateLimitResetCreditsSummary: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let credits: [RateLimitResetCredit]

    public init(
        availableCount: Int,
        credits: [RateLimitResetCredit] = [],
        expirationDates: [Date] = []
    ) {
        self.availableCount = max(0, availableCount)
        self.credits = Self.uniqueSorted(
            credits + expirationDates.map {
                RateLimitResetCredit(status: nil, title: nil, grantedAt: nil, expiresAt: $0)
            }
        )
    }

    public var nearestExpiration: Date? {
        expirationDates.first
    }

    public var expirationDates: [Date] {
        Self.uniqueSortedDates(credits.compactMap(\.expiresAt))
    }

    enum CodingKeys: String, CodingKey {
        case availableCount
        case available_count
        case expirationDates
        case expiration_dates
        case expirationTimes
        case expiration_times
        case expirations
        case expiresAt
        case expires_at
        case credits
        case data
        case items
        case resetCredits
        case reset_credits
        case opportunities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedAvailableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount)
            ?? container.decodeIfPresent(Int.self, forKey: .available_count)

        var credits: [RateLimitResetCredit] = []
        credits += Self.decodeCredits(from: container, forKey: .credits)
        credits += Self.decodeCredits(from: container, forKey: .data)
        credits += Self.decodeCredits(from: container, forKey: .items)
        credits += Self.decodeCredits(from: container, forKey: .resetCredits)
        credits += Self.decodeCredits(from: container, forKey: .reset_credits)
        credits += Self.decodeCredits(from: container, forKey: .opportunities)

        var expirationDates: [Date] = []
        expirationDates += Self.decodeDates(from: container, forKey: .expirationDates)
        expirationDates += Self.decodeDates(from: container, forKey: .expiration_dates)
        expirationDates += Self.decodeDates(from: container, forKey: .expirationTimes)
        expirationDates += Self.decodeDates(from: container, forKey: .expiration_times)
        expirationDates += Self.decodeDates(from: container, forKey: .expirations)

        if credits.isEmpty {
            expirationDates += Self.decodeDates(from: container, forKey: .credits)
            expirationDates += Self.decodeDates(from: container, forKey: .data)
            expirationDates += Self.decodeDates(from: container, forKey: .items)
            expirationDates += Self.decodeDates(from: container, forKey: .resetCredits)
            expirationDates += Self.decodeDates(from: container, forKey: .reset_credits)
            expirationDates += Self.decodeDates(from: container, forKey: .opportunities)
        }

        if let expiresAt = try container.decodeIfPresent(FlexibleDate.self, forKey: .expiresAt)?.date {
            expirationDates.append(expiresAt)
        }
        if let expiresAt = try container.decodeIfPresent(FlexibleDate.self, forKey: .expires_at)?.date {
            expirationDates.append(expiresAt)
        }

        self.init(
            availableCount: decodedAvailableCount ?? max(credits.count, expirationDates.count),
            credits: credits,
            expirationDates: expirationDates
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(availableCount, forKey: .availableCount)
        try container.encode(credits, forKey: .credits)
    }

    private static func decodeCredits(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [RateLimitResetCredit] {
        (try? container.decodeIfPresent([RateLimitResetCredit].self, forKey: key)) ?? []
    }

    private static func decodeDates(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [Date] {
        ((try? container.decodeIfPresent([FlexibleDate].self, forKey: key)) ?? []).map(\.date)
    }

    private static func uniqueSorted(_ credits: [RateLimitResetCredit]) -> [RateLimitResetCredit] {
        var seen = Set<String>()
        let unique = credits.filter { credit in
            let key = [
                credit.status ?? "",
                credit.title ?? "",
                credit.grantedAt.map { "\($0.timeIntervalSince1970)" } ?? "",
                credit.expiresAt.map { "\($0.timeIntervalSince1970)" } ?? ""
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }

        return unique.sorted { lhs, rhs in
            let lhsExpires = lhs.expiresAt ?? .distantFuture
            let rhsExpires = rhs.expiresAt ?? .distantFuture
            if lhsExpires != rhsExpires {
                return lhsExpires < rhsExpires
            }
            return (lhs.grantedAt ?? .distantPast) < (rhs.grantedAt ?? .distantPast)
        }
    }

    private static func uniqueSortedDates(_ dates: [Date]) -> [Date] {
        Array(Set(dates)).sorted()
    }
}

public struct RateLimitResetCredit: Codable, Equatable, Sendable {
    public let status: String?
    public let title: String?
    public let grantedAt: Date?
    public let expiresAt: Date?

    public init(status: String?, title: String?, grantedAt: Date?, expiresAt: Date?) {
        self.status = status
        self.title = title
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case status
        case title
        case grantedAt
        case granted_at
        case createdAt
        case created_at
        case expiresAt
        case expires_at
        case expirationDate
        case expiration_date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        grantedAt = try container.decodeIfPresent(FlexibleDate.self, forKey: .grantedAt)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .granted_at)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .createdAt)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .created_at)?.date
        expiresAt = try container.decodeIfPresent(FlexibleDate.self, forKey: .expiresAt)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .expires_at)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .expirationDate)?.date
            ?? container.decodeIfPresent(FlexibleDate.self, forKey: .expiration_date)?.date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(grantedAt.map { Int64($0.timeIntervalSince1970.rounded()) }, forKey: .grantedAt)
        try container.encodeIfPresent(expiresAt.map { Int64($0.timeIntervalSince1970.rounded()) }, forKey: .expiresAt)
    }
}

private struct FlexibleDate: Codable, Equatable, Sendable {
    let date: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int64.self) {
            date = DateCoding.dateFromFlexibleEpoch(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            if value > 10_000_000_000 {
                date = Date(timeIntervalSince1970: value / 1_000)
            } else {
                date = Date(timeIntervalSince1970: value)
            }
            return
        }

        if let value = try? container.decode(String.self) {
            if let epoch = Int64(value) {
                date = DateCoding.dateFromFlexibleEpoch(epoch)
                return
            }

            if let parsed = DateCoding.parseISODate(value) {
                date = parsed
                return
            }
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an epoch or ISO-8601 date."
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Int64(date.timeIntervalSince1970.rounded()))
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
