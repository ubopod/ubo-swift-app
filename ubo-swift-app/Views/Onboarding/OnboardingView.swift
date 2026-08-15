//
//  OnboardingView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            title: "Welcome to Ubo",
            description: "Your Ubo Pod, made mobile. Connect to monitor, control, and interact with your device from anywhere on the network or remotely."
        ),
        OnboardingPage(
            icon: "gauge.with.dots.needle.bottom.50percent",
            title: "See it at a glance",
            description: "Track full application and system stats (CPU, Memory, Storage, etc), and sensor readings in real time."
        ),
        OnboardingPage(
            icon: "list.bullet",
            title: "Your Pod's screen, on your phone",
            description: "Browse menus, respond to prompts, and chat with the on-device assistant — all mirrored live from your Ubo."
        ),
        OnboardingPage(
            icon: "qrcode",
            title: "WiFi onboarding made easy",
            description: "Create a WiFi QR code to pass credentials to your Ubo Pod in a single step."
        ),
        OnboardingPage(
            icon: "cart",
            title: "Don't have a Ubo yet?",
            description: "Get a ready-to-go UboPod, or deploy the software only version yourself on a Raspberry Pi.",
            links: [
                OnboardingLink(title: "Order a UboPod", url: URL(string: "https://shop.getubo.com/products/ubo-pro-4-and-5")!),
                OnboardingLink(title: "Set up on Raspberry Pi", url: URL(string: "https://github.com/ubopod/ubo_app/releases")!)
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif

            // Bottom button area
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Skip") {
                        hasCompletedOnboarding = true
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    var links: [OnboardingLink] = []
}

struct OnboardingLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 16)

            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !page.links.isEmpty {
                VStack(spacing: 12) {
                    ForEach(page.links) { link in
                        Link(destination: link.url) {
                            Text(link.title)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
