//
//  UboDeeplink.swift
//  ubo-swift-app
//
//  The `ubo://` URL scheme used to hand a text-input demand from a lean
//  client (Apple TV) to a phone that can type. The TV encodes its own
//  connection + the pending input id into a QR code; scanning it opens the
//  iPhone app, which connects to the same core and lands on the input form.
//  Input forms are shared state (`active_inputs` streams to every client),
//  so this is a bootstrap + focus convenience, not a data channel.
//

import Foundation

enum UboDeeplink {
    static let scheme = "ubo"
    static let inputHost = "input"

    struct InputRequest {
        let host: String
        let port: Int
        let useTLS: Bool
        let inputId: String
    }

    /// Builds `ubo://input?host=…&port=…&tls=0|1&id=…` for the on-TV QR code.
    static func inputURL(host: String, port: Int, useTLS: Bool, inputId: String) -> URL? {
        guard !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = inputHost
        components.queryItems = [
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "tls", value: useTLS ? "1" : "0"),
            URLQueryItem(name: "id", value: inputId),
        ]
        return components.url
    }

    /// Parses an incoming `ubo://input?…` URL on the receiving phone.
    static func parseInput(_ url: URL) -> InputRequest? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == inputHost else {
            return nil
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let host = value("host"), !host.isEmpty else { return nil }
        let port = Int(value("port") ?? "") ?? 50051
        let useTLS = value("tls") == "1"
        return InputRequest(host: host, port: port, useTLS: useTLS, inputId: value("id") ?? "")
    }
}
