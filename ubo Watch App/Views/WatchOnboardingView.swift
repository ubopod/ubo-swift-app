//
//  WatchOnboardingView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI

struct WatchOnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("Welcome to Ubo")
                    .font(.headline)

                Text("Control your device from your wrist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .tag(0)

            // Page 2: Features
            VStack(spacing: 12) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("Remote Control")
                    .font(.headline)

                Text("Navigate menus and monitor stats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .tag(1)

            // Page 3: Get Started
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("Ready to Go")
                    .font(.headline)

                Button("Get Started") {
                    hasCompletedOnboarding = true
                }
                .buttonStyle(.borderedProminent)
            }
            .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchOnboardingView(hasCompletedOnboarding: .constant(false))
}
