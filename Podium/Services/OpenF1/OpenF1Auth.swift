//
//  OpenF1Auth.swift
//  Podium
//

import Foundation

/// Получение и кэш OAuth2 токена для Open F1 API (реальное время).
final class OpenF1Auth {
    static let shared = OpenF1Auth()

    private let tokenURL = URL(string: "https://api.openf1.org/token")!
    private let session = URLSession.shared

    private var cachedToken: String?
    private var tokenExpiresAt: Date?
    /// После 401/429 на `/token` не дёргаем сеть снова сразу — иначе десятки параллельных `decode` устраивают шторм и ловят 429.
    private var authFailureUntil: Date?
    private var inFlightRefresh: Task<String?, Never>?
    private let lock = NSLock()

    private init() {}

    private static var lastLoggedCache: Date?
    private static let cacheLogInterval: TimeInterval = 60
    private static var lastLoggedCooldown: Date?
    private static let cooldownLogInterval: TimeInterval = 120

    /// Возвращает Bearer токен (из кэша или запрашивает новый). nil если не удалось.
    func getToken() async -> String? {
        lock.lock()
        let now = Date()
        if let until = authFailureUntil, until > now {
            lock.unlock()
            let last = Self.lastLoggedCooldown ?? .distantPast
            if now.timeIntervalSince(last) >= Self.cooldownLogInterval {
                Self.lastLoggedCooldown = now
                let sec = Int(until.timeIntervalSince(now).rounded(.up))
                print("[OpenF1] token skipped (cooldown ~\(sec)s — no paid subscription or rate limited)")
            }
            return nil
        }
        if let token = cachedToken, let expires = tokenExpiresAt, expires > now.addingTimeInterval(60) {
            lock.unlock()
            let last = Self.lastLoggedCache ?? .distantPast
            if now.timeIntervalSince(last) >= Self.cacheLogInterval {
                Self.lastLoggedCache = now
                print("[OpenF1] token from cache")
            }
            return token
        }
        if let existing = inFlightRefresh {
            lock.unlock()
            return await existing.value
        }
        let task = Task<String?, Never> { await self.refreshTokenFromNetwork() }
        inFlightRefresh = task
        lock.unlock()
        let result = await task.value
        lock.lock()
        inFlightRefresh = nil
        lock.unlock()
        return result
    }

    private func refreshTokenFromNetwork() async -> String? {
        let outcome = await fetchTokenWithStatus()
        lock.lock()
        defer { lock.unlock() }
        if let token = outcome.token {
            cachedToken = token
            tokenExpiresAt = Date().addingTimeInterval(3600)
            authFailureUntil = nil
            print("[OpenF1] token obtained (fresh)")
            return token
        }
        let code = outcome.statusCode
        let backoff: TimeInterval = {
            switch code {
            case 429:
                return 300
            case 401, 403:
                return 900
            case let c? where (500...599).contains(c):
                return 120
            default:
                return 90
            }
        }()
        authFailureUntil = Date().addingTimeInterval(backoff)
        if let c = code {
            print("[OpenF1] token HTTP \(c) — pause token requests \(Int(backoff))s (avoid 429 storm)")
        } else {
            print("[OpenF1] token error — pause token requests \(Int(backoff))s")
        }
        return nil
    }

    private func fetchTokenWithStatus() async -> (token: String?, statusCode: Int?) {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "username=\(OpenF1Secrets.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(OpenF1Secrets.password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (nil, nil)
            }
            let code = http.statusCode
            guard (200...299).contains(code) else {
                return (nil, code)
            }
            struct TokenResponse: Decodable { let access_token: String }
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            return (decoded.access_token, code)
        } catch {
            print("[OpenF1] token network: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    /// После 401/429 на `/token` Bearer недоступен — не запускать тяжёлые батчи (circuitInfo и т.п.), пока не истечёт пауза.
    var isTokenEndpointInBackoff: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let until = authFailureUntil else { return false }
        return until > Date()
    }
}
