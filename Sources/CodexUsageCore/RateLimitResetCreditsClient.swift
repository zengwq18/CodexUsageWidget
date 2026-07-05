import Foundation

public enum RateLimitResetCreditsClientError: Error, LocalizedError, Equatable, Sendable {
    case accessTokenMissing
    case unauthorized
    case invalidResponse
    case unexpectedStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .accessTokenMissing:
            "Codex access token was not found."
        case .unauthorized:
            "Codex access token is invalid or the Authorization header was rejected."
        case .invalidResponse:
            "The rate-limit reset credits response was invalid."
        case let .unexpectedStatus(statusCode):
            "The rate-limit reset credits request failed with HTTP \(statusCode)."
        }
    }
}

public struct RateLimitResetCreditsClient: Sendable {
    private let authFileURL: URL
    private let endpointURL: URL

    public init(
        authFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json"),
        endpointURL: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    ) {
        self.authFileURL = authFileURL
        self.endpointURL = endpointURL
    }

    public func fetch() async throws -> RateLimitResetCreditsSummary {
        let token = try accessToken()
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexUsageWidget", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RateLimitResetCreditsClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return try JSONDecoder().decode(RateLimitResetCreditsSummary.self, from: data)
        case 401:
            throw RateLimitResetCreditsClientError.unauthorized
        default:
            throw RateLimitResetCreditsClientError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    private func accessToken() throws -> String {
        let data = try Data(contentsOf: authFileURL)
        let auth = try JSONDecoder().decode(CodexAuthFile.self, from: data)
        guard let token = auth.accessToken, !token.isEmpty else {
            throw RateLimitResetCreditsClientError.accessTokenMissing
        }
        return token
    }
}

private struct CodexAuthFile: Decodable {
    let tokens: Tokens?
    let chatgptAuthTokens: Tokens?
    let rootAccessToken: String?

    var accessToken: String? {
        tokens?.accessToken ?? chatgptAuthTokens?.accessToken ?? rootAccessToken
    }

    enum CodingKeys: String, CodingKey {
        case tokens
        case chatgptAuthTokens
        case rootAccessToken = "access_token"
    }

    struct Tokens: Decodable {
        let accessToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }
}
