//
//  ProgressBanner.swift
//  UnfollowChecker
//

internal import SwiftUI

/// Slim global banner shown at the bottom of every tab while a cleanup is running.
/// Tap it to open the full-screen CleanupProgressView.
struct ProgressBanner: View {
    @Environment(UnfollowService.self) private var unfollowService
    @Binding var showProgressSheet: Bool

    var body: some View {
        switch unfollowService.state {
        case .running(let cur, let tot):
            bannerRow(cur: cur, tot: tot)
        default:
            EmptyView()
        }
    }

    private func bannerRow(cur: Int, tot: Int) -> some View {
        let pct = tot > 0 ? Int(Double(cur) / Double(tot) * 100) : 0
        return Button { showProgressSheet = true } label: {
            HStack(spacing: 12) {
                ProgressView(value: tot > 0 ? Double(cur) / Double(tot) : 0)
                    .progressViewStyle(.linear)
                    .tint(Color.roast)
                    .frame(width: 48)

                Text("Cleaning \(pct)%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.espresso)

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(Color.latte)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.borderless)
    }
}
