//
//  WatchStatusBarOverlay.swift
//  ubo Watch App
//
//  Compact CPU/RAM/clock chip shown atop `WatchDeviceView`. Mirrors the
//  GUI client's status bar for parity context.
//

import SwiftUI
import UboSwift

struct WatchStatusBarOverlay: View {
    let bar: StatusBarData?
    let cpuPercent: Float
    let ramPercent: Float
    let temperature: Float?

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                Text("\(Int(cpuPercent))%")
            }
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                Text("\(Int(ramPercent))%")
            }
            if let temp = temperature {
                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                    Text("\(Int(temp))°")
                }
            }

            Spacer()

            if let bar, !bar.clock.isEmpty {
                Text(bar.clock)
                    .font(.system(size: 9, design: .monospaced))
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
