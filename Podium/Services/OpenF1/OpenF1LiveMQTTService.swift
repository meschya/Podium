//
//  OpenF1LiveMQTTService.swift
//  Podium
//
//  Лайв по документации OpenF1 (https://openf1.org/auth.html):
//  MQTT broker mqtt.openf1.org, порт 8883 (TLS). Username = любой, password = OAuth2 токен. Топик v1/location.
//

import Foundation
import CocoaMQTT

private let locationTopic = "v1/location"

/// Real-time позиции машин через MQTT — как в примере Python в доках (нативный MQTT/TLS, не WebSocket).
final class OpenF1LiveMQTTService: NSObject {
    static let shared = OpenF1LiveMQTTService()

    private var mqtt: CocoaMQTT?
    private let queue = DispatchQueue(label: "openf1.mqtt")

    /// Вызывается на каждом сообщении v1/location.
    var onLocation: (@Sendable (OpenF1Location) -> Void)?

    override private init() {
        super.init()
    }

    /// Подключиться и подписаться на v1/location. По документации: username — любой, password — токен.
    func connect() async {
        guard let token = await OpenF1Auth.shared.getToken() else {
            print("[Live] MQTT connect skipped: no token")
            return
        }
        print("[Live] MQTT connecting (mqtt.openf1.org:8883)...")
        queue.async { [weak self] in
            self?.connectWith(token: token)
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            self?.mqtt?.disconnect()
            self?.mqtt = nil
            print("[Live] MQTT disconnected")
        }
    }

    /// По документации: mqtt.openf1.org, порт 8883 (TLS), username + password = токен. Без WebSocket.
    private func connectWith(token: String) {
        guard mqtt == nil else { return }

        let clientID = "Podium-\(UUID().uuidString.prefix(8))"
        let client = CocoaMQTT(clientID: String(clientID), host: "mqtt.openf1.org", port: 8883)
        client.username = OpenF1Secrets.email
        client.password = token
        client.enableSSL = true
        client.keepAlive = 60
        client.autoReconnect = true
        client.delegateQueue = queue

        var messageCount = 0
        client.didConnectAck = { mqtt, ack in
            if ack == .accept {
                print("[Live] MQTT connected, subscribing to v1/location")
                mqtt.subscribe(locationTopic, qos: .qos0)
            } else {
                print("[Live] MQTT connect ack=\(ack.rawValue) (not accept)")
            }
        }

        client.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let loc = Self.parseLocation(message) else { return }
            messageCount += 1
            if messageCount <= 3 { print("[Live] MQTT message #\(messageCount) driver=\(loc.driverNumber)") }
            self?.onLocation?(loc)
        }

        client.didDisconnect = { [weak self] _, reason in
            print("[Live] MQTT didDisconnect reason=\(reason)")
            self?.queue.async { self?.mqtt = nil }
        }

        mqtt = client
        _ = client.connect(timeout: 15)
    }

    private static func parseLocation(_ message: CocoaMQTTMessage) -> OpenF1Location? {
        let data = Data(message.payload)
        return try? JSONDecoder().decode(OpenF1Location.self, from: data)
    }
}
