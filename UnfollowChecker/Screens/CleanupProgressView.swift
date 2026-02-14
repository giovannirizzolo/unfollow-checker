//
//  CleanupProgressView.swift
//  UnfollowChecker
//

internal import SwiftUI
internal import Combine

/// Full-screen cleanup progress view — launched from the ProgressBanner or home card.
struct CleanupProgressView: View {
    @Environment(UnfollowService.self) private var unfollowService
    @Environment(\.dismiss) private var dismiss

    @State private var statusIndex = 0
    private let statusMessages = [
        "Taking it nice and slow…",
        "Respecting Instagram's limits…",
        "Cleaning up your feed…",
        "Almost there, stay patient…",
        "Your account stays safe…",
    ]

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()

                switch unfollowService.state {
                case .running(let cur, let tot):
                    runningBody(cur: cur, tot: tot)

                case .paused:
                    pausedBody

                case .done(let succeeded, let failed):
                    doneBody(succeeded: succeeded, failed: failed)

                case .failed(let msg):
                    failedBody(msg: msg)

                default:
                    EmptyView()
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                statusIndex = (statusIndex + 1) % statusMessages.count
            }
        }
    }

    // MARK: - Running

    @ViewBuilder
    private func runningBody(cur: Int, tot: Int) -> some View {
        let pct = tot > 0 ? Int(Double(cur) / Double(tot) * 100) : 0

        // Large percentage
        Text("\(pct)%")
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .foregroundStyle(Color.espresso)

        Text("\(cur) of \(tot)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color.latte)

        // Gradient progress bar
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.latte.opacity(0.18))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.latte, Color.roast],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: tot > 0
                            ? max(28, geo.size.width * CGFloat(cur) / CGFloat(tot))
                            : 0,
                        height: 14
                    )
                    .animation(.easeInOut(duration: 0.35), value: cur)
            }
        }
        .frame(height: 14)

        // Rotating calm status text
        Text(statusMessages[statusIndex])
            .font(.subheadline)
            .foregroundStyle(Color.latte)
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.4), value: statusIndex)

        // Stop button
        Button {
            unfollowService.pause()
        } label: {
            Label("Stop cleanup", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.latte.opacity(0.15))
                .foregroundStyle(Color.roast)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.borderless)
        .padding(.top, 8)
    }

    // MARK: - Paused

    private var pausedBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.latte)

            Text("Paused")
                .font(.title2.bold())
                .foregroundStyle(Color.espresso)

            Text("You can resume at any time.")
                .font(.subheadline)
                .foregroundStyle(Color.latte)

            Button("Done") { dismiss() }
                .foregroundStyle(Color.roast)
        }
    }

    // MARK: - Done

    private func doneBody(succeeded: Int, failed: Int) -> some View {
        VStack(spacing: 20) {
            Text("✅")
                .font(.system(size: 64))

            Text("All done!")
                .font(.title2.bold())
                .foregroundStyle(Color.espresso)

            if succeeded > 0 {
                Text("Unfollowed \(succeeded) account\(succeeded == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Color.roast)
            }
            if failed > 0 {
                Text("\(failed) unavailable")
                    .font(.caption)
                    .foregroundStyle(Color.latte)
            }

            Button("Close") { dismiss() }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.roast.opacity(0.12))
                .foregroundStyle(Color.roast)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .buttonStyle(.borderless)
        }
    }

    // MARK: - Failed

    private func failedBody(msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red.opacity(0.7))

            Text("Something went wrong")
                .font(.title3.bold())
                .foregroundStyle(Color.espresso)

            Text(msg)
                .font(.subheadline)
                .foregroundStyle(Color.latte)
                .multilineTextAlignment(.center)

            Button("Close") { dismiss() }
                .foregroundStyle(Color.roast)
        }
    }
}
