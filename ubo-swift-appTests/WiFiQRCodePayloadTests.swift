//
//  WiFiQRCodePayloadTests.swift
//  ubo-swift-appTests
//

import Testing
@testable import ubo_swift_app

struct WiFiQRCodePayloadTests {

    @Test func buildsWPAPayload() {
        let payload = WiFiQRCodePayload.build(ssid: "MyNetwork", password: "hunter2", security: .wpa)
        #expect(payload == "WIFI:T:WPA;S:MyNetwork;P:hunter2;;")
    }

    @Test func buildsOpenNetworkPayloadWithoutPasswordField() {
        let payload = WiFiQRCodePayload.build(ssid: "GuestWiFi", password: "", security: .none)
        #expect(payload == "WIFI:T:nopass;S:GuestWiFi;;")
    }

    @Test func escapesReservedCharactersInSSIDAndPassword() {
        let payload = WiFiQRCodePayload.build(ssid: "a;b,c:d\"e\\f", password: "p;w", security: .wpa)
        #expect(payload == "WIFI:T:WPA;S:a\\;b\\,c\\:d\\\"e\\\\f;P:p\\;w;;")
    }

    @Test func buildsWEPPayload() {
        let payload = WiFiQRCodePayload.build(ssid: "OldRouter", password: "abc123", security: .wep)
        #expect(payload == "WIFI:T:WEP;S:OldRouter;P:abc123;;")
    }
}
