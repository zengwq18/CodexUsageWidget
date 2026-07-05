import CodexUsageCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw CheckFailure.failed(message) }
    return value
}

func checkDailyUsageBucketsMapToLastSevenDays() throws {
    let payload = Data("""
    {
      "summary": {},
      "dailyUsageBuckets": [
        { "startDate": "2026-06-10", "tokens": 1200 },
        { "startDate": "2026-06-14", "tokens": 3400 }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(AccountUsageResponse.self, from: payload)
    let now = try require(DateCoding.dayFormatter.date(from: "2026-06-14"), "failed to build fixed date")
    let days = response.dailyUsage(now: now)

    try check(days.map(\.date) == [
        "2026-06-08",
        "2026-06-09",
        "2026-06-10",
        "2026-06-11",
        "2026-06-12",
        "2026-06-13",
        "2026-06-14"
    ], "daily buckets should map to the last seven dates")
    try check(days.first { $0.date == "2026-06-10" }?.tokens == 1200, "2026-06-10 token count mismatch")
    try check(days.first { $0.date == "2026-06-14" }?.tokens == 3400, "2026-06-14 token count mismatch")
    try check(days.allSatisfy { $0.source == .account }, "official usage should be marked as account source")
}

func checkMissingDailyUsageBucketsBecomeZeros() throws {
    let payload = Data(#"{ "summary": {} }"#.utf8)
    let response = try JSONDecoder().decode(AccountUsageResponse.self, from: payload)
    let now = try require(DateCoding.dayFormatter.date(from: "2026-06-14"), "failed to build fixed date")
    let days = response.dailyUsage(now: now)

    try check(days.count == 7, "missing daily buckets should still produce seven days")
    try check(days.allSatisfy { $0.tokens == 0 }, "missing daily buckets should be zeros")
}

func checkDuplicateDailyUsageBucketsAreSummed() throws {
    let payload = Data("""
    {
      "summary": {},
      "dailyUsageBuckets": [
        { "startDate": "2026-06-14", "tokens": 1000 },
        { "startDate": "2026-06-14", "tokens": 2500 }
      ]
    }
    """.utf8)

    let response = try JSONDecoder().decode(AccountUsageResponse.self, from: payload)
    let now = try require(DateCoding.dayFormatter.date(from: "2026-06-14"), "failed to build fixed date")
    let days = response.dailyUsage(now: now)

    try check(days.first { $0.date == "2026-06-14" }?.tokens == 3500, "duplicate daily buckets should be summed")
}

func checkRateLimitsPreferCodexBucketAndClassifyWindows() throws {
    let payload = Data("""
    {
      "rateLimits": {
        "limitId": "fallback",
        "primary": { "usedPercent": 91, "windowDurationMins": 300, "resetsAt": 1781100000 },
        "secondary": { "usedPercent": 92, "windowDurationMins": 10080, "resetsAt": 1781200000 }
      },
      "rateLimitsByLimitId": {
        "codex": {
          "limitId": "codex",
          "limitName": "Codex",
          "primary": { "usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1781100000 },
          "secondary": { "usedPercent": 40, "windowDurationMins": 10080, "resetsAt": null }
        }
      }
    }
    """.utf8)

    let response = try JSONDecoder().decode(AccountRateLimitsResponse.self, from: payload)
    let windows = response.selectedRateLimitSnapshot.rateWindows

    try check(response.selectedRateLimitSnapshot.limitId == "codex", "codex bucket should be preferred")
    try check(windows.fiveHour?.kind == .fiveHour, "primary 300 minute window should be fiveHour")
    try check(windows.fiveHour?.remainingPercent == 75, "five hour remaining percent mismatch")
    try check(windows.weekly?.kind == .weekly, "secondary 10080 minute window should be weekly")
    try check(windows.weekly?.remainingPercent == 60, "weekly remaining percent mismatch")
    try check(windows.weekly?.resetsAt == nil, "nil reset time should stay nil")
}

func checkRateLimitsFallbackToSingleBucket() throws {
    let payload = Data("""
    {
      "rateLimits": {
        "limitId": "fallback",
        "primary": { "usedPercent": 10, "windowDurationMins": 300, "resetsAt": null },
        "secondary": { "usedPercent": 55, "windowDurationMins": 10080, "resetsAt": 1781200000 }
      }
    }
    """.utf8)

    let response = try JSONDecoder().decode(AccountRateLimitsResponse.self, from: payload)
    let windows = response.selectedRateLimitSnapshot.rateWindows

    try check(response.selectedRateLimitSnapshot.limitId == "fallback", "single bucket should be used as fallback")
    try check(windows.fiveHour?.remainingPercent == 90, "fallback five hour remaining percent mismatch")
    try check(windows.weekly?.remainingPercent == 45, "fallback weekly remaining percent mismatch")
}

func checkRateLimitResetCreditsDecodeCountAndExpirations() throws {
    let payload = Data("""
    {
      "rateLimits": {
        "limitId": "codex",
        "primary": { "usedPercent": 10, "windowDurationMins": 300, "resetsAt": null },
        "secondary": { "usedPercent": 20, "windowDurationMins": 10080, "resetsAt": null }
      },
      "rateLimitResetCredits": {
        "available_count": 3,
        "expirationDates": [1781100000],
        "credits": [
          {
            "status": "available",
            "title": "Full reset (Weekly + 5 hr)",
            "granted_at": "2026-06-12T04:07:03Z",
            "expires_at": "2026-07-12T04:07:03Z"
          },
          { "expirationDate": 1781200000000 }
        ]
      }
    }
    """.utf8)

    let response = try JSONDecoder().decode(AccountRateLimitsResponse.self, from: payload)
    let credits = try require(response.rateLimitResetCredits, "reset credits should decode")

    try check(credits.availableCount == 3, "reset credit count mismatch")
    try check(credits.expirationDates.count == 3, "reset credit expirations should decode from arrays and objects")
    let fullReset = try require(
        credits.credits.first { $0.title == "Full reset (Weekly + 5 hr)" },
        "detailed reset credit should decode"
    )
    try check(fullReset.status == "available", "reset credit status mismatch")
    try check(
        fullReset.grantedAt == DateCoding.parseISODate("2026-06-12T04:07:03Z"),
        "reset credit granted time mismatch"
    )
    try check(
        fullReset.expiresAt == DateCoding.parseISODate("2026-07-12T04:07:03Z"),
        "reset credit expiration time mismatch"
    )
    try check(
        credits.nearestExpiration == DateCoding.dateFromFlexibleEpoch(1781100000),
        "nearest reset credit expiration should be sorted first"
    )
}

func checkTokenCountEventsAggregateByLocalDay() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("rollout.jsonl")
    let jsonl = """
    {"timestamp":"2026-06-13T01:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":100}}}}
    {"timestamp":"2026-06-13T02:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":250}}}}
    {"timestamp":"2026-06-14T01:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":400}}}}
    {"timestamp":"2026-06-14T02:00:00.000Z","type":"event_msg","payload":{"type":"not_token_count","info":{"last_token_usage":{"total_tokens":999}}}}
    {"timestamp":"2026-06-14T03:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{}}}
    not json
    """
    try jsonl.data(using: .utf8)?.write(to: file)

    let parser = LocalUsageLogParser(roots: [root])
    let now = try require(DateCoding.dayFormatter.date(from: "2026-06-14"), "failed to build fixed date")
    let days = parser.recentDailyUsage(now: now)

    try check(days.count == 7, "local parser should produce seven days")
    try check(days.first { $0.date == "2026-06-13" }?.tokens == 350, "2026-06-13 local token sum mismatch")
    try check(days.first { $0.date == "2026-06-14" }?.tokens == 400, "2026-06-14 local token sum mismatch")
    try check(days.allSatisfy { $0.source == .localEstimate }, "local parser should mark localEstimate source")
}

func checkRecentWindowWithoutEventsReturnsZeros() throws {
    let root = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("rollout.jsonl")
    try """
    {"timestamp":"2026-05-01T01:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":999}}}}
    """.data(using: .utf8)?.write(to: file)

    let parser = LocalUsageLogParser(roots: [root])
    let now = try require(DateCoding.dayFormatter.date(from: "2026-06-14"), "failed to build fixed date")
    let days = parser.recentDailyUsage(now: now)

    try check(days.count == 7, "empty recent window should produce seven days")
    try check(days.allSatisfy { $0.tokens == 0 }, "old events should not count toward recent window")
}

func makeTempDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexUsageWidgetChecks", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

let checks: [(String, () throws -> Void)] = [
    ("dailyUsageBucketsMapToLastSevenDays", checkDailyUsageBucketsMapToLastSevenDays),
    ("missingDailyUsageBucketsBecomeZeros", checkMissingDailyUsageBucketsBecomeZeros),
    ("duplicateDailyUsageBucketsAreSummed", checkDuplicateDailyUsageBucketsAreSummed),
    ("rateLimitsPreferCodexBucketAndClassifyWindows", checkRateLimitsPreferCodexBucketAndClassifyWindows),
    ("rateLimitsFallbackToSingleBucket", checkRateLimitsFallbackToSingleBucket),
    ("rateLimitResetCreditsDecodeCountAndExpirations", checkRateLimitResetCreditsDecodeCountAndExpirations),
    ("tokenCountEventsAggregateByLocalDay", checkTokenCountEventsAggregateByLocalDay),
    ("recentWindowWithoutEventsReturnsZeros", checkRecentWindowWithoutEventsReturnsZeros)
]

for (name, run) in checks {
    try run()
    print("PASS \(name)")
}

print("All CodexUsageCore checks passed.")
