//
//  F1LiveTimingSignalRService.swift
//  Podium
//
//  Официальный F1 Live Timing (livetiming.formula1.com SignalR).
//  Документация: https://dweik.xyz/post/f1-signalr-endpoint/
//  Position.z по подписке даёт реальное расположение: X, Y (координаты на трассе, 1/10 м — FastF1).
//  Альтернативно приходит Position 0...1 (прогресс по кругу). Fallback — TimingData (порядок по позиции).
//

import Foundation
import Compression

/// Реальные координаты машины на трассе из Position.z (X, Y в единицах API, обычно 1/10 м).
struct F1LiveCoordinate: Equatable {
    var x: Int
    var y: Int
}

private let baseURL = "https://livetiming.formula1.com/signalr"
private let connectionDataJSON = #"[{"name":"Streaming"}]"#
private var connectionDataEncoded: String {
    connectionDataJSON.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? connectionDataJSON
}

/// Токен в URL должен кодировать + и / (сервер иначе отдаёт -1011).
private func encodeConnectionToken(_ token: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "+/")
    return token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
}

/// Из Set-Cookie берём только первую пару name=value (Cookie заголовок).
private func firstCookie(from setCookie: String) -> String {
    let part = setCookie.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? setCookie
    return part.trimmingCharacters(in: .whitespaces)
}

/// Сервис подключения к официальному F1 Live Timing (SignalR), подписка на Position.z для карты.
final class F1LiveTimingSignalRService {
    static let shared = F1LiveTimingSignalRService()

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var connectionToken: String?
    private var cookie: String?
    private var receiveCount = 0
    /// Накопленные TimingData.Lines (RacingNumber -> line data) для fallback, когда Position.z не приходит.
    private var timingDataLines: [String: [String: Any]] = [:]

    /// Обновление позиций по прогрессу 0...1 (когда API отдаёт Position, не координаты). Вызывается на main.
    var onPositions: (([Int: CGFloat]) -> Void)?
    /// Реальное расположение машин по подписке: [driverNumber: (x, y)] — координаты на трассе. Вызывается на main.
    var onCoordinates: (([Int: F1LiveCoordinate]) -> Void)?

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func connect() async {
        if webSocketTask != nil { return }
        do {
            print("[F1Live] Negotiating...")
            let (token, cookie) = try await negotiate()
            self.connectionToken = token
            self.cookie = cookie
            try await connectWebSocket(token: token, cookie: cookie)
            await subscribe()
            print("[F1Live] SignalR subscribe sent (Position.z). If handshake fails, check -1011 = geo or cookie.")
        } catch {
            print("[F1Live] SignalR failed: \(error)")
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionToken = nil
        cookie = nil
        print("[F1Live] SignalR disconnected")
    }

    // MARK: - Negotiate

    private func negotiate() async throws -> (token: String, cookie: String) {
        let urlString = "\(baseURL)/negotiate?connectionData=\(connectionDataEncoded)&clientProtocol=1.5"
        guard let url = URL(string: urlString) else { throw F1LiveError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("BestHTTP", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip,identity", forHTTPHeaderField: "Accept-Encoding")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw F1LiveError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        struct NegotiateResponse: Decodable {
            let ConnectionToken: String
        }
        let decoded = try JSONDecoder().decode(NegotiateResponse.self, from: data)
        let cookieValue = http.value(forHTTPHeaderField: "Set-Cookie") ?? ""
        return (decoded.ConnectionToken, cookieValue)
    }

    // MARK: - WebSocket

    private func connectWebSocket(token: String, cookie: String) async throws {
        let encodedToken = encodeConnectionToken(token)
        let cookieValue = firstCookie(from: cookie)
        let urlString = "wss://livetiming.formula1.com/signalr/connect?clientProtocol=1.5&transport=webSockets&connectionToken=\(encodedToken)&connectionData=\(connectionDataEncoded)"
        guard let url = URL(string: urlString) else { throw F1LiveError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("BestHTTP", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip,identity", forHTTPHeaderField: "Accept-Encoding")
        if !cookieValue.isEmpty {
            request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveLoop()
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let s = String(data: data, encoding: .utf8) { self?.handleMessage(s) }
                @unknown default:
                    break
                }
            case .failure(let error):
                print("[F1Live] WebSocket error: \(error)")
            }
            self?.receiveLoop()
        }
    }

    private func subscribe() async {
        let msg = """
        {"H":"Streaming","M":"Subscribe","A":[["Position.z","Heartbeat","TimingData"]],"I":1}
        """
        webSocketTask?.send(.string(msg)) { _ in }
    }

    // MARK: - Parse

    private func handleMessage(_ text: String) {
        receiveCount += 1
        if receiveCount <= 5 {
            let preview = String(text.prefix(300))
            print("[F1Live] message #\(receiveCount): \(preview)\(text.count > 300 ? "…" : "")")
        }

        // 1) Обычное JSON-сообщение
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            processSignalRMessage(json)
        }

        // 2) Поле G = base64(gzip(data)) — по документации F1, распаковываем и обрабатываем
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let gBase64 = json["G"] as? String,
           let inner = decompressG(base64: gBase64) {
            processSignalRMessage(inner)
        }
    }

    /// Обработка одного сообщения: R (начальное состояние) и M (массив вызовов "feed").
    private func processSignalRMessage(_ json: [String: Any]) {
        var positionZProgress: [Int: CGFloat]?
        var positionZCoords: [Int: F1LiveCoordinate]?

        if let r = json["R"] as? [String: Any] {
            if let payload = r["Position.z"] {
                positionZCoords = parsePositionCoordinates(payload)
                if positionZCoords == nil { positionZProgress = parsePositionProgress(payload) }
                if positionZCoords != nil, receiveCount <= 20 { print("[F1Live] Position.z (R) coordinates: \(positionZCoords!.count) drivers") }
                else if positionZProgress != nil, receiveCount <= 20 { print("[F1Live] Position.z (R) progress: \(positionZProgress!.count) drivers") }
            }
            if let timingData = r["TimingData"] as? [String: Any], let lines = timingData["Lines"] as? [String: [String: Any]] {
                timingDataLines = lines
            }
        }

        let mArray = json["M"] as? [[String: Any]] ?? []
        for item in mArray {
            let method = (item["M"] as? String) ?? ""
            let args = item["A"] as? [Any] ?? []
            guard method == "feed", args.count >= 2,
                  let streamName = args[0] as? String else { continue }
            let payload = args[1]
            if streamName == "Position.z" {
                if let coords = parsePositionCoordinates(payload) {
                    positionZCoords = coords
                    positionZProgress = nil
                    if receiveCount <= 20 { print("[F1Live] Position.z coordinates: \(coords.count) drivers") }
                } else if let progress = parsePositionProgress(payload) {
                    positionZProgress = progress
                    positionZCoords = nil
                    if receiveCount <= 20 { print("[F1Live] Position.z progress: \(progress.count) drivers") }
                } else if receiveCount <= 20 { print("[F1Live] Position.z unparsed: \(String(describing: payload).prefix(200))") }
            } else if streamName == "TimingData", let lines = (payload as? [String: Any])?["Lines"] as? [String: [String: Any]] {
                for (key, value) in lines { timingDataLines[key] = value }
            }
        }

        if let coords = positionZCoords, !coords.isEmpty {
            if receiveCount <= 30 { print("[F1Live] sending \(coords.count) coordinates (Position.z real)") }
            DispatchQueue.main.async { [weak self] in self?.onCoordinates?(coords) }
        } else if let positions = positionZProgress, !positions.isEmpty {
            if receiveCount <= 30 { print("[F1Live] sending \(positions.count) positions (Position.z progress)") }
            DispatchQueue.main.async { [weak self] in self?.onPositions?(positions) }
        } else if let progress = progressFromTimingDataLines(), !progress.isEmpty {
            if receiveCount <= 30 { print("[F1Live] sending \(progress.count) positions (TimingData fallback)") }
            DispatchQueue.main.async { [weak self] in self?.onPositions?(progress) }
        }
    }

    /// По порядку позиций в TimingData строим прогресс 0...1 вдоль трассы (fallback, когда Position.z нет).
    /// Включаем всех гонщиков из Lines: с позицией — по порядку, без позиции/retired — в конце.
    private func progressFromTimingDataLines() -> [Int: CGFloat]? {
        var withPosition: [(driverNumber: Int, position: Int)] = []
        var withoutPosition: [Int] = []
        for (key, line) in timingDataLines {
            guard let num = Int(key) else { continue }
            let retired = (line["Retired"] as? Bool) == true
            let pos: Int? = (line["Position"] as? String).flatMap(Int.init) ?? (line["Position"] as? Int)
            if let p = pos, p > 0, !retired {
                withPosition.append((num, p))
            } else {
                withoutPosition.append(num)
            }
        }
        guard !withPosition.isEmpty || !withoutPosition.isEmpty else { return nil }
        var out: [Int: CGFloat] = [:]
        let sorted = withPosition.sorted { $0.position < $1.position }
        let totalCount = sorted.count + withoutPosition.count
        let divisor = max(1, totalCount - 1)
        for (index, item) in sorted.enumerated() {
            out[item.driverNumber] = CGFloat(index) / CGFloat(divisor)
        }
        for (idx, num) in withoutPosition.enumerated() {
            out[num] = CGFloat(sorted.count + idx) / CGFloat(divisor)
        }
        return out
    }

    /// Распаковка G: base64 → gzip decompress → JSON. По доке F1 — gzip; пробуем также zlib.
    private func decompressG(base64: String) -> [String: Any]? {
        guard let raw = Data(base64Encoded: base64), !raw.isEmpty else { return nil }
        let decompressed: Data?
        if raw.count >= 2 && raw[0] == 0x1f && raw[1] == 0x8b {
            decompressed = decompressGzip(raw)
        } else {
            decompressed = (try? (raw as NSData).decompressed(using: .zlib)) as Data?
        }
        guard let data = decompressed,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    /// Gzip: 10-байтный заголовок, затем raw deflate. Добавляем zlib-заголовок (78 9c) и распаковываем через .zlib.
    private func decompressGzip(_ data: Data) -> Data? {
        guard data.count > 10 else { return nil }
        let deflate = data.subdata(in: 10 ..< data.count)
        let withZlibHeader = Data([0x78, 0x9c]) + deflate
        return (try? (withZlibHeader as NSData).decompressed(using: .zlib)) as Data?
    }

    /// Position.z с подпиской: реальные координаты X, Y на трассе (1/10 м по FastF1). Поля X, Y или x, y.
    private func parsePositionCoordinates(_ payload: Any) -> [Int: F1LiveCoordinate]? {
        if let str = payload as? String, let data = str.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            return parsePositionCoordinates(decoded)
        }
        func intFrom(_ entry: [String: Any], keys: String...) -> Int? {
            for k in keys {
                if let v = entry[k] as? Int { return v }
                if let v = entry[k] as? Double { return Int(v.rounded()) }
                if let v = entry[k] as? String { return Int(v) }
            }
            return nil
        }
        if let arr = payload as? [[String: Any]] {
            var out: [Int: F1LiveCoordinate] = [:]
            for entry in arr {
                let num = (entry["RacingNumber"] as? String).flatMap { Int($0) }
                    ?? (entry["RacingNumber"] as? Int)
                    ?? (entry["DriverNumber"] as? Int)
                guard let n = num,
                      let x = intFrom(entry, keys: "X", "x"),
                      let y = intFrom(entry, keys: "Y", "y") else { continue }
                out[n] = F1LiveCoordinate(x: x, y: y)
            }
            return out.isEmpty ? nil : out
        }
        if let dict = payload as? [String: Any] {
            var out: [Int: F1LiveCoordinate] = [:]
            for (key, val) in dict {
                guard let num = Int(key),
                      let obj = val as? [String: Any],
                      let x = intFrom(obj, keys: "X", "x"),
                      let y = intFrom(obj, keys: "Y", "y") else { continue }
                out[num] = F1LiveCoordinate(x: x, y: y)
            }
            return out.isEmpty ? nil : out
        }
        return nil
    }

    /// Position.z без координат: прогресс по кругу 0...1 (Position или Progress).
    private func parsePositionProgress(_ payload: Any) -> [Int: CGFloat]? {
        if let str = payload as? String, let data = str.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            return parsePositionProgress(decoded)
        }
        if let arr = payload as? [[String: Any]] {
            var out: [Int: CGFloat] = [:]
            for entry in arr {
                let num = (entry["RacingNumber"] as? String).flatMap { Int($0) }
                    ?? (entry["RacingNumber"] as? Int)
                    ?? (entry["DriverNumber"] as? Int)
                guard let n = num else { continue }
                let pos = (entry["Position"] as? Double).map { CGFloat($0) }
                    ?? (entry["Position"] as? Int).map { CGFloat($0) }
                    ?? (entry["Progress"] as? Double).map { CGFloat($0) }
                if let p = pos, p >= 0, p <= 1 { out[n] = p }
            }
            return out.isEmpty ? nil : out
        }
        if let dict = payload as? [String: Any] {
            var out: [Int: CGFloat] = [:]
            for (key, val) in dict {
                guard let num = Int(key) else { continue }
                let d = (val as? Double) ?? (val as? Int).map { Double($0) }
                guard let v = d, v >= 0, v <= 1 else { continue }
                out[num] = CGFloat(v)
            }
            return out.isEmpty ? nil : out
        }
        return nil
    }
}

enum F1LiveError: Error, LocalizedError {
    case invalidURL
    case server(Int)
    case websocketFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .server(let c): return "HTTP \(c)"
        case .websocketFailed: return "WebSocket failed"
        }
    }
}

