import Darwin
import Foundation

public enum CodexAppServerError: Error, LocalizedError, Equatable {
    case executableMissing(String)
    case processTerminated
    case invalidResponse(String)
    case rpcError(code: Int?, message: String)
    case writeFailed
    case requestTimedOut(String)
    case ioError(String)

    public var errorDescription: String? {
        switch self {
        case let .executableMissing(path):
            "Codex executable not found at \(path)."
        case .processTerminated:
            "Codex app-server terminated unexpectedly."
        case let .invalidResponse(line):
            "Invalid app-server response: \(line)"
        case let .rpcError(_, message):
            message
        case .writeFailed:
            "Failed to write request to Codex app-server."
        case let .requestTimedOut(method):
            "Codex app-server request timed out: \(method)."
        case let .ioError(message):
            message
        }
    }
}

public actor CodexAppServerClient {
    private let executablePath: String
    private let requestTimeoutSeconds: TimeInterval
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var lineBuffer = Data()
    private var nextRequestId = 1
    private var didInitialize = false

    public init(
        executablePath: String? = nil,
        requestTimeoutSeconds: TimeInterval = 8
    ) {
        self.executablePath = executablePath ?? Self.defaultExecutablePath()
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    deinit {
        process?.terminate()
    }

    private static func defaultExecutablePath() -> String {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex"
        ]
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:)) ?? candidates[0]
    }

    public func fetchAccountUsage() async throws -> [DailyUsage] {
        let response: AccountUsageResponse = try await send(
            method: "account/usage/read",
            params: Optional<JSONNull>.none
        )
        return response.dailyUsage()
    }

    public func fetchRateLimits() async throws -> (
        fiveHour: RateWindow?,
        weekly: RateWindow?,
        resetCredits: RateLimitResetCreditsSummary?
    ) {
        let response: AccountRateLimitsResponse = try await send(
            method: "account/rateLimits/read",
            params: Optional<JSONNull>.none
        )
        let windows = response.selectedRateLimitSnapshot.rateWindows
        return (windows.fiveHour, windows.weekly, response.rateLimitResetCredits)
    }

    public nonisolated func observeRateLimitUpdates(pollIntervalSeconds: UInt64 = 300) -> AsyncStream<RateLimitSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        let response: AccountRateLimitsResponse = try await self.send(
                            method: "account/rateLimits/read",
                            params: Optional<JSONNull>.none
                        )
                        continuation.yield(response.rateLimitsByLimitId?["codex"] ?? response.rateLimits)
                    } catch {
                        // The repository performs explicit refreshes and cache fallback.
                    }

                    try? await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func stop() {
        process?.terminate()
        process = nil
        input = nil
        output = nil
        didInitialize = false
        lineBuffer.removeAll()
    }

    private func ensureStarted() throws {
        guard process == nil else { return }
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CodexAppServerError.executableMissing(executablePath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--stdio"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        try process.run()
        try Self.setNonBlocking(stdoutPipe.fileHandleForReading.fileDescriptor)

        self.process = process
        self.input = stdinPipe.fileHandleForWriting
        self.output = stdoutPipe.fileHandleForReading
    }

    private static func setNonBlocking(_ fileDescriptor: Int32) throws {
        let flags = fcntl(fileDescriptor, F_GETFL, 0)
        guard flags >= 0 else {
            throw CodexAppServerError.ioError("Failed to read app-server stdout flags.")
        }

        guard fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            throw CodexAppServerError.ioError("Failed to set app-server stdout to non-blocking mode.")
        }
    }

    private func ensureInitialized() async throws {
        guard !didInitialize else { return }
        try ensureStarted()

        struct InitializeParams: Encodable {
            let clientInfo: ClientInfo
            let capabilities: Capabilities

            struct ClientInfo: Encodable {
                let name: String
                let title: String
                let version: String
            }

            struct Capabilities: Encodable {
                let experimentalApi: Bool
            }
        }

        let params = InitializeParams(
            clientInfo: .init(
                name: "codex_usage_widget",
                title: "Codex Usage Widget",
                version: "0.1.0"
            ),
            capabilities: .init(experimentalApi: true)
        )

        let _: EmptyResult = try await sendInitializedRequest(id: 0, method: "initialize", params: params)
        try writeNotification(method: "initialized", params: JSONNull())
        didInitialize = true
    }

    private func send<T: Decodable, P: Encodable>(method: String, params: P?) async throws -> T {
        try await ensureInitialized()
        let id = nextRequestId
        nextRequestId += 1
        return try await sendInitializedRequest(id: id, method: method, params: params)
    }

    private func sendInitializedRequest<T: Decodable, P: Encodable>(id: Int, method: String, params: P?) async throws -> T {
        try writeRequest(id: id, method: method, params: params)

        while true {
            let line = try await readLine(method: method)
            guard let data = line.data(using: .utf8) else {
                throw CodexAppServerError.invalidResponse(line)
            }

            let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
            guard envelope.id == id else { continue }

            if let error = envelope.error {
                throw CodexAppServerError.rpcError(code: error.code, message: error.message)
            }

            guard let result = envelope.result else {
                if T.self == EmptyResult.self, let empty = EmptyResult() as? T {
                    return empty
                }
                throw CodexAppServerError.invalidResponse(line)
            }

            return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(result))
        }
    }

    private func writeRequest<P: Encodable>(id: Int, method: String, params: P?) throws {
        var object: [String: Any] = [
            "id": id,
            "method": method
        ]
        object["params"] = try encodeJSONObject(params)
        try writeJSONObject(object)
    }

    private func writeNotification<P: Encodable>(method: String, params: P?) throws {
        var object: [String: Any] = [
            "method": method
        ]
        object["params"] = try encodeJSONObject(params)
        try writeJSONObject(object)
    }

    private func writeJSONObject(_ object: [String: Any]) throws {
        guard let input else { throw CodexAppServerError.processTerminated }
        let data = try JSONSerialization.data(withJSONObject: object)
        var line = data
        line.append(0x0A)

        do {
            try input.write(contentsOf: line)
        } catch {
            throw CodexAppServerError.writeFailed
        }
    }

    private func encodeJSONObject<P: Encodable>(_ value: P?) throws -> Any {
        guard let value else { return NSNull() }
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func readLine(method: String) async throws -> String {
        guard let output else { throw CodexAppServerError.processTerminated }
        let deadline = Date().addingTimeInterval(requestTimeoutSeconds)
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            try Task.checkCancellation()

            if let newline = lineBuffer.firstIndex(of: 0x0A) {
                let lineData = lineBuffer[..<newline]
                lineBuffer.removeSubrange(...newline)
                return String(decoding: lineData, as: UTF8.self)
            }

            if let process, !process.isRunning {
                stop()
                throw CodexAppServerError.processTerminated
            }

            if Date() >= deadline {
                stop()
                throw CodexAppServerError.requestTimedOut(method)
            }

            let count = Darwin.read(output.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                lineBuffer.append(contentsOf: buffer.prefix(count))
                continue
            }

            if count == 0 {
                stop()
                throw CodexAppServerError.processTerminated
            }

            let error = errno
            if error == EAGAIN || error == EWOULDBLOCK || error == EINTR {
                try await Task.sleep(nanoseconds: 50_000_000)
                continue
            }

            stop()
            throw CodexAppServerError.ioError("Failed to read app-server stdout: errno \(error).")
        }
    }
}

private struct ResponseEnvelope: Decodable {
    let id: Int?
    let result: JSONValue?
    let error: RPCError?

    enum CodingKeys: String, CodingKey {
        case id
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        error = try container.decodeIfPresent(RPCError.self, forKey: .error)

        if container.contains(.result), try !container.decodeNil(forKey: .result) {
            result = try container.decode(JSONValue.self, forKey: .result)
        } else {
            result = nil
        }
    }
}

private enum JSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: JSONValue].self) {
            self = .object(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

private struct RPCError: Decodable {
    let code: Int?
    let message: String
}

private struct EmptyResult: Codable {}

private struct JSONNull: Codable {}

public struct AccountUsageResponse: Decodable, Sendable {
    let dailyUsageBuckets: [DailyBucket]?

    struct DailyBucket: Decodable, Sendable {
        let startDate: String
        let tokens: Int64
    }

    public func dailyUsage(now: Date = Date()) -> [DailyUsage] {
        let buckets = dailyUsageBuckets ?? []
        let byDate = buckets.reduce(into: [String: Int64]()) { totals, bucket in
            totals[bucket.startDate, default: 0] += bucket.tokens
        }
        return DateCoding.lastSevenDateKeys(now: now).map { key in
            DailyUsage(date: key, tokens: byDate[key] ?? 0, source: .account)
        }
    }
}

public struct AccountRateLimitsResponse: Decodable, Sendable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    public let rateLimitResetCredits: RateLimitResetCreditsSummary?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitId
        case rateLimitResetCredits
        case rate_limits
        case rate_limits_by_limit_id
        case rate_limit_reset_credits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rateLimits = try container.decodeIfPresent(RateLimitSnapshot.self, forKey: .rateLimits)
            ?? container.decode(RateLimitSnapshot.self, forKey: .rate_limits)
        rateLimitsByLimitId = try container.decodeIfPresent([String: RateLimitSnapshot].self, forKey: .rateLimitsByLimitId)
            ?? container.decodeIfPresent([String: RateLimitSnapshot].self, forKey: .rate_limits_by_limit_id)
        rateLimitResetCredits = try container.decodeIfPresent(RateLimitResetCreditsSummary.self, forKey: .rateLimitResetCredits)
            ?? container.decodeIfPresent(RateLimitResetCreditsSummary.self, forKey: .rate_limit_reset_credits)
    }

    public var selectedRateLimitSnapshot: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}
