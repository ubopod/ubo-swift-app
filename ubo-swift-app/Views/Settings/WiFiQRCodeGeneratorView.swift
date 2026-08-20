//
//  WiFiQRCodeGeneratorView.swift
//  ubo-swift-app
//
//  Builds a standard `WIFI:` QR payload from user-entered credentials so a
//  Ubo Pod can join a network by scanning the phone's screen — no typing
//  required on the device itself.
//

import SwiftUI
import UboAppKit

#if os(iOS)
import CoreLocation
import NetworkExtension
#endif

enum WiFiSecurityType: String, CaseIterable, Identifiable {
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

enum WiFiQRCodePayload {
    /// Builds a `WIFI:T:...;S:...;P:...;;` payload per the format most QR
    /// scanners (including Wi-Fi settings screens) recognize.
    static func build(ssid: String, password: String, security: WiFiSecurityType) -> String {
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

#if os(iOS)
/// Fetches the SSID of the network the phone is currently on, so the SSID
/// field can be prefilled. Requires location authorization — without it,
/// `NEHotspotNetwork.fetchCurrent` returns a network with no readable SSID.
@MainActor
final class CurrentWiFiSSIDFetcher: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    func fetchSSID() async -> String? {
        await requestAuthorizationIfNeeded()
        return await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }

    private func requestAuthorizationIfNeeded() async {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.delegate = self
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        }
    }
}
#endif

struct WiFiQRCodeGeneratorView: View {
    @State private var ssid = ""
    @State private var password = ""
    @State private var security: WiFiSecurityType = .wpa
    @State private var qrImage: Image?

    #if os(iOS)
    @State private var ssidFetcher = CurrentWiFiSSIDFetcher()
    #endif

    var body: some View {
        Form {
            Section {
                TextField("SSID", text: $ssid)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onChange(of: ssid) { qrImage = nil }

                Picker("Security", selection: $security) {
                    ForEach(WiFiSecurityType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .onChange(of: security) { qrImage = nil }

                if security != .none {
                    SecureField("Password", text: $password)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: password) { qrImage = nil }
                }
            } header: {
                Text("Wi-Fi Details")
            } footer: {
                Text("The SSID is prefilled from the network you're currently connected to. Clear it to enter a different one.")
            }

            Section {
                Button("Generate QR Code") {
                    qrImage = QRCodeImage.generate(from: WiFiQRCodePayload.build(ssid: ssid, password: password, security: security))
                }
                .disabled(ssid.isEmpty)
            }

            if let qrImage {
                Section {
                    VStack(spacing: 12) {
                        qrImage
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: 280)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Hold this up to the Ubo Pod's camera")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Wi-Fi QR Code")
        #if os(iOS)
        .task {
            guard ssid.isEmpty, let currentSSID = await ssidFetcher.fetchSSID() else { return }
            ssid = currentSSID
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        WiFiQRCodeGeneratorView()
    }
}
