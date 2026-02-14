//
//  SafetyOnboardingView.swift
//  UnfollowChecker
//

internal import SwiftUI
import UIKit

struct SafetyOnboardingView: View {
    @AppStorage("hasSeenSafetyOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    private let pages = SafetyOnboardingPage.pages

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(pages.indices, id: \.self) { index in
                SafetyOnboardingCard(
                    page: pages[index],
                    isLast: index == pages.count - 1,
                    onContinue: {
                        if index == pages.count - 1 {
                            finish()
                        } else {
                            withAnimation { currentPage = index + 1 }
                        }
                    },
                    onSkip: finish
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled(false)
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        hasSeenOnboarding = true
        dismiss()
    }
}

#Preview {
    SafetyOnboardingView()
}
