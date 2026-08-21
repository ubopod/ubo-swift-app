//
//  WatchWiFiQRCodeView.swift
//  ubo Watch App
//
//  Watch-local port of the phone app's `WiFiQRCodeGeneratorView` — builds a
//  standard `WIFI:` QR payload so a brand-new Ubo Pod (not on any network
//  yet) can join Wi-Fi by scanning the watch's screen with its camera. No
//  SSID autofill here: that path uses CoreLocation/NetworkExtension, which
//  aren't available on watchOS, so SSID/password are typed manually — same
//  input method the connect form's Host/Port fields already use. Same
//  per-target duplication pattern as `WatchSensorDisplay`/`SensorDisplay`
//  (separate file, not a shared package).
//

import SwiftUI
import UboAppKit

enum WatchWiFiSecurityType: String, CaseIterable, Identifiable {
    case wpa
    case wep
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wpa: return "WPA/WPA2"
        case .wep: return "WEP"
        case .none: return "None (Open)"
        }
    }

    /// The `T:` field value in the `WIFI:` QR payload.
    var qrCodeValue: String {
        switch self {
        case .wpa: return "WPA"
        case .wep: return "WEP"
        case .none: return "nopass"
        }
    }
}

enum WatchWiFiQRCodePayload {
    /// Builds a `WIFI:T:...;S:...;P:...;;` payload per the format most QR
    /// scanners (including Wi-Fi settings screens) recognize.
    static func build(ssid: String, password: String, security: WatchWiFiSecurityType) -> String {
        var payload = "WIFI:T:\(security.qrCodeValue);S:\(escape(ssid));"
        if security != .none {
            payload += "P:\(escape(password));"
        }
        payload += ";"
        return payload
    }

    /// Escapes the characters the spec reserves as field/payload delimiters.
    private static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            if "\\;,\":".contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }
}

struct WatchWiFiQRCodeView: View {
    @State private var ssid = ""
    @State private var password = ""
    @State private var security: WatchWiFiSecurityType = .wpa
    @State private var qrImage: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TextField("SSID", text: $ssid)
                    .onChange(of: ssid) { qrImage = nil }

                Picker("Security", selection: $security) {
                    ForEach(WatchWiFiSecurityType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .onChange(of: security) { qrImage = nil }

                if security != .none {
                    SecureField("Password", text: $password)
                        .onChange(of: password) { qrImage = nil }
                }

                Button("Generate QR Code") {
                    qrImage = QRCodeImage.generate(from: WatchWiFiQRCodePayload.build(ssid: ssid, password: password, security: security))
                }
                .disabled(ssid.isEmpty)

                if let qrImage {
                    qrImage
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 140)
                        .padding(4)
                        .background(.white)
                        .cornerRadius(8)

                    Text("Hold this up to the Ubo Pod's camera")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Wi-Fi QR Code")
    }
}

#Preview {
    NavigationStack {
        WatchWiFiQRCodeView()
    }
}
