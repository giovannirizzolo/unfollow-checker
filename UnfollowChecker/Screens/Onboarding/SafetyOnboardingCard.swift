//
//  SafetyOnboardingCard.swift
//  UnfollowChecker
//

internal import SwiftUI

/// A single page in the safety onboarding flow.
struct SafetyOnboardingCard: View {
    let page: SafetyOnboardingPage
    let isLast: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 2) {
                Spacer()
                // Icon
                Text(page.emoji)
                    .font(.system(size: 64))
                    .padding(.bottom, 24)

                // Title
                Text(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

                // Body
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(Color.roast)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // Bullet points
                if !page.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(page.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Text("•")
                                    .foregroundStyle(Color.latte)
                                Text(bullet)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.espresso)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }

                Spacer()

                // CTA
                Button(action: onContinue) {
                    Text(isLast ? "Got it, let's go" : "Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.roast)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 32)

                // Skip (only on non-last pages)
                if !isLast {
                    Button("Skip", action: onSkip)
                        .font(.subheadline)
                        .foregroundStyle(Color.latte)
                        .padding(.top, 16)
                }

                Spacer().frame(height: 40)
            }
        }
    }
}

// MARK: - Page model

struct SafetyOnboardingPage {
    let emoji:   String
    let title:   String
    let body:    String
    let bullets: [String]

    static let pages: [SafetyOnboardingPage] = [
        SafetyOnboardingPage(
            emoji: "🛡️",
            title: "Safety First",
            body: "This app uses Instagram's private API. To keep your account safe, unfollowing is rate-limited.",
            bullets: [
                "Max 60 unfollows per hour",
                "8–15 second delay between each",
                "You can stop and resume anytime",
            ]
        ),
        SafetyOnboardingPage(
            emoji: "⏳",
            title: "Be Patient",
            body: "If you have many accounts to clean up, it may take several sessions.",
            bullets: [
                "Whitelist accounts you want to keep",
                "The queue saves your progress",
                "Pending requests are skipped automatically",
            ]
        ),
        SafetyOnboardingPage(
            emoji: "✅",
            title: "Stay in Control",
            body: "You're always in charge. Nothing happens without your tap.",
            bullets: [
                "Review the list before starting",
                "Stop at any time with the Stop button",
                "Done accounts won't appear again",
            ]
        ),
    ]
}
