import Foundation

public struct UsageRepository: Sendable {
    private let appServer: CodexAppServerClient
    private let localParser: LocalUsageLogParser
    private let cacheStore: CacheStore

    public init(
        appServer: CodexAppServerClient = CodexAppServerClient(),
        localParser: LocalUsageLogParser = LocalUsageLogParser(),
        cacheStore: CacheStore = CacheStore()
    ) {
        self.appServer = appServer
        self.localParser = localParser
        self.cacheStore = cacheStore
    }

    public func refresh() async -> UsageSnapshot {
        let cached = cacheStore.load()

        var isStale = false
        let days: [DailyUsage]
        do {
            days = try await appServer.fetchAccountUsage()
        } catch {
            let localDays = localParser.recentDailyUsage()
            let hasLocalTokens = localDays.contains { $0.tokens > 0 }
            if hasLocalTokens {
                days = localDays
            } else if let cached {
                days = cached.days.map {
                    DailyUsage(date: $0.date, tokens: $0.tokens, source: .cache)
                }
            } else {
                days = UsageSnapshot.empty.days
            }
            isStale = true
        }

        let fiveHour: RateWindow?
        let weekly: RateWindow?
        let resetCredits: RateLimitResetCreditsSummary?
        do {
            let limits = try await appServer.fetchRateLimits()
            fiveHour = limits.fiveHour
            weekly = limits.weekly
            resetCredits = limits.resetCredits
        } catch {
            fiveHour = cached?.fiveHour
            weekly = cached?.weekly
            resetCredits = cached?.resetCredits
            isStale = true
        }

        let snapshot = UsageSnapshot(
            days: normalized(days),
            fiveHour: fiveHour,
            weekly: weekly,
            resetCredits: resetCredits,
            updatedAt: Date(),
            isStale: isStale
        )

        try? cacheStore.save(snapshot)
        return snapshot
    }

    public func observeRateLimitUpdates() -> AsyncStream<RateLimitSnapshot> {
        appServer.observeRateLimitUpdates()
    }

    private func normalized(_ days: [DailyUsage]) -> [DailyUsage] {
        let byDate = days.reduce(into: [String: DailyUsage]()) { normalized, day in
            if let existing = normalized[day.date] {
                normalized[day.date] = DailyUsage(
                    date: day.date,
                    tokens: existing.tokens + day.tokens,
                    source: existing.source
                )
            } else {
                normalized[day.date] = day
            }
        }
        return DateCoding.lastSevenDateKeys().map { key in
            byDate[key] ?? DailyUsage(date: key, tokens: 0, source: .cache)
        }
    }
}
