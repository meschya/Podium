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
    private let lock = NSLock()

    private init() {}

    private static var lastLoggedCache: Date?
    private static let cacheLogInterval: TimeInterval = 60

    /// Возвращает Bearer токен (из кэша или запрашивает новый). nil если не удалось.
    func getToken() async -> String? {
        lock.lock()
        let now = Date()
        if let token = cachedToken, let expires = tokenExpiresAt, expires > now.addingTimeInterval(60) {
            lock.unlock()
            let last = Self.lastLoggedCache ?? .distantPast
            if now.timeIntervalSince(last) >= Self.cacheLogInterval {
                Self.lastLoggedCache = now
                print("[OpenF1] token from cache")
            }
            return token
        }
        lock.unlock()

        guard let newToken = await fetchToken() else {
            print("[OpenF1] token failed (nil)")
            return nil
        }

        lock.lock()
        cachedToken = newToken
        tokenExpiresAt = Date().addingTimeInterval(3600)
        lock.unlock()
        print("[OpenF1] token obtained (fresh)")
        return newToken
    }

    private func fetchToken() async -> String? {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "username=\(OpenF1Secrets.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(OpenF1Secrets.password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("[OpenF1] token HTTP \(code)")
                return nil
            }
            struct TokenResponse: Decodable { let access_token: String }
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            return decoded.access_token
        } catch {
            print("[OpenF1] token error: \(error)")
            return nil
        }
    }
}
