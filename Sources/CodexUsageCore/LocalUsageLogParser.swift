import Foundation

public struct LocalUsageLogParser: Sendable {
    public let roots: [URL]

    public init(codexHome: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")) {
        self.roots = [
            codexHome.appendingPathComponent("sessions", isDirectory: true),
            codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        ]
    }

    public init(roots: [URL]) {
        self.roots = roots
    }

    public func recentDailyUsage(now: Date = Date()) -> [DailyUsage] {
        let keys = DateCoding.lastSevenDateKeys(now: now)
        let wanted = Set(keys)
        var totals = Dictionary(uniqueKeysWithValues: keys.map { ($0, Int64(0)) })

        for fileURL in jsonlFiles() {
            parse(fileURL: fileURL, wantedDays: wanted, totals: &totals)
        }

        return keys.map { key in
            DailyUsage(date: key, tokens: totals[key] ?? 0, source: .localEstimate)
        }
    }

    private func jsonlFiles() -> [URL] {
        roots.flatMap { root -> [URL] in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return enumerator.compactMap { item -> URL? in
                guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
                return url
            }
        }
    }

    private func parse(fileURL: URL, wantedDays: Set<String>, totals: inout [String: Int64]) {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        defer { try? handle.close() }

        var buffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                consume(lineData: Data(lineData), wantedDays: wantedDays, totals: &totals)
            }
        }

        if !buffer.isEmpty {
            consume(lineData: buffer, wantedDays: wantedDays, totals: &totals)
        }
    }

    private func consume(lineData: Data, wantedDays: Set<String>, totals: inout [String: Int64]) {
        guard let event = try? JSONDecoder().decode(TokenCountEvent.self, from: lineData),
              event.type == "event_msg",
              event.payload.type == "token_count",
              let timestamp = DateCoding.parseISODate(event.timestamp)
        else {
            return
        }

        let day = DateCoding.dayKey(for: timestamp)
        guard wantedDays.contains(day) else { return }

        let tokens = event.payload.info?.lastTokenUsage?.totalTokens ?? 0
        guard tokens > 0 else { return }
        totals[day, default: 0] += tokens
    }
}

private struct TokenCountEvent: Decodable {
    let timestamp: String
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String
        let info: Info?
    }

    struct Info: Decodable {
        let lastTokenUsage: TokenUsage?

        enum CodingKeys: String, CodingKey {
            case lastTokenUsage = "last_token_usage"
        }
    }

    struct TokenUsage: Decodable {
        let totalTokens: Int64?

        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
        }
    }
}
