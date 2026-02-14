//
//  AssistModeView.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

internal import SwiftUI

// MARK: - Assist mode (swipe-card flow)

struct AssistModeView: View {
    let users: [String]

    @Environment(WhitelistStore.self) var store
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimating = false      // guard against double-fire

    @AppStorage("hasSeenSwipeOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    @State private var unfollowCount = 0
    @State private var keepCount = 0

    // MARK: - Derived

    private var remaining: [String] { Array(users.dropFirst(currentIndex)) }
    private var isAllDone: Bool { currentIndex >= users.count }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            if isAllDone {
                summaryScreen
            } else {
                VStack(spacing: 0) {
                    progressBar
                    cardStack
                    hintRow
                }
            }

            if showOnboarding { onboardingOverlay }
        }
        .navigationTitle(isAllDone ? "Done" : "\(currentIndex + 1) / \(users.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { if !hasSeenOnboarding { showOnboarding = true } }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.latte.opacity(0.15)
                Color.roast
                    .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(users.count, 1)))
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Card stack

    private var cardStack: some View {
        ZStack {
            // Card behind — keyed by username so SwiftUI creates a fresh view each time
            if remaining.count > 1 {
                SwipeCard(username: remaining[1], dragOffset: .zero, isInteractive: false)
                    .id("bg-\(remaining[1])")
                    .scaleEffect(0.93)
                    .offset(y: 16)
                    .allowsHitTesting(false)
            }

            // Top card
            if let top = remaining.first {
                SwipeCard(username: top, dragOffset: dragOffset, isInteractive: true)
                    .id("top-\(top)")
                    .gesture(swipeDragGesture(for: top))
                    .zIndex(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Hint row

    private var hintRow: some View {
        HStack {
            Label("Unfollow", systemImage: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red.opacity(0.75))
            Spacer()
            Label("Keep", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.roast.opacity(0.75))
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 18)
    }

    // MARK: - Gesture

    private func swipeDragGesture(for username: String) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimating else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAnimating else { return }
                let dx = value.translation.width
                if dx < -110 {
                    commitSwipe(username: username, left: true)
                } else if dx > 110 {
                    commitSwipe(username: username, left: false)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func commitSwipe(username: String, left: Bool) {
        isAnimating = true

        if left {
            // Open Instagram immediately — user unfollows while card animates away
            unfollowCount += 1
            let app = URL(string: "instagram://user?username=\(username)")!
            let web = URL(string: "https://instagram.com/\(username)")!
            openURL(UIApplication.shared.canOpenURL(app) ? app : web)
        } else {
            keepCount += 1
            store.addToActive(username)
        }

        let targetX: CGFloat = left ? -700 : 700
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: targetX, height: dragOffset.height * 0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            store.markDone(username)
            currentIndex += 1
            dragOffset = .zero
            isAnimating = false
        }
    }

    // MARK: - Summary screen

    private var summaryScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.latte)

            Text("All reviewed!")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.espresso)

            HStack(spacing: 48) {
                statBadge(count: unfollowCount, label: "Unfollowed", icon: "xmark.circle.fill", color: .red)
                statBadge(count: keepCount,     label: "Kept",       icon: "heart.fill",        color: Color.roast)
            }

            Text("Instagram was opened for each unfollow.\nYou can close this now.")
                .font(.subheadline)
                .foregroundStyle(Color.latte)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button { dismiss() } label: {
                Text("Back to Home")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.roast)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.borderless)

            Spacer()
        }
    }

    private func statBadge(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title).foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.espresso)
            Text(label).font(.caption).foregroundStyle(Color.latte)
        }
    }

    // MARK: - Onboarding overlay

    private var onboardingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.draw.fill")
                        .font(.title2).foregroundStyle(Color.latte)
                    Text("Swipe to decide")
                        .font(.title2.weight(.bold)).foregroundStyle(Color.espresso)
                }
                VStack(alignment: .leading, spacing: 14) {
                    bullet("arrow.left",            "Swipe left — opens Instagram to unfollow")
                    bullet("arrow.right",           "Swipe right — keeps & whitelists them")
                    bullet("arrow.up.right.square", "Tap the card to preview the profile first")
                }
                Button {
                    hasSeenOnboarding = true
                    showOnboarding = false
                } label: {
                    Text("Let's go")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.roast)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.foam)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(Color.roast)
            Text(text).font(.subheadline).foregroundStyle(Color.espresso)
        }
    }
}

// MARK: - Swipe card

struct SwipeCard: View {
    let username: String
    let dragOffset: CGSize
    let isInteractive: Bool

    @Environment(\.openURL) private var openURL

    private var progress: CGFloat { min(abs(dragOffset.width) / 110, 1) }
    private var goingLeft: Bool { dragOffset.width < 0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.foam)
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)

            if isInteractive && dragOffset.width != 0 {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        goingLeft
                            ? Color.red.opacity(0.22 * progress)
                            : Color.green.opacity(0.22 * progress)
                    )
            }

            VStack(spacing: 0) {
                HStack {
                    Text("UNFOLLOW")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.red)
                        .opacity(goingLeft ? Double(progress) : 0)
                        .padding(.leading, 22)
                    Spacer()
                    Text("KEEP")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color(red: 0.1, green: 0.72, blue: 0.35))
                        .opacity(goingLeft ? 0 : Double(progress))
                        .padding(.trailing, 22)
                }
                .frame(height: 44)
                .padding(.top, 16)

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.latte.opacity(0.22))
                        .frame(width: 108, height: 108)
                    Image(systemName: "person.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.latte)
                }

                Text(username)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.espresso)
                    .padding(.top, 18)
                    .padding(.horizontal, 16)
                    .multilineTextAlignment(.center)

                Spacer()

                Button { openInstagram() } label: {
                    Label("Open in Instagram", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.roast)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.latte.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .padding(.bottom, 30)
            }
        }
        .frame(height: 440)
        .rotationEffect(.degrees(isInteractive ? Double(dragOffset.width / 22) : 0))
        .offset(isInteractive ? dragOffset : .zero)
    }

    private func openInstagram() {
        let app = URL(string: "instagram://user?username=\(username)")!
        let web = URL(string: "https://instagram.com/\(username)")!
        openURL(UIApplication.shared.canOpenURL(app) ? app : web)
    }
}

// MARK: - Preview

#Preview {
    let store = WhitelistStore()
    return NavigationStack {
        AssistModeView(users: ["cristiano", "zuck", "elonmusk", "timcook", "nasa"])
            .environment(store)
    }
}
