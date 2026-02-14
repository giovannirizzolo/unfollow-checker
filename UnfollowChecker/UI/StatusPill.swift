//
//  StatusPill.swift
//  UnfollowChecker
//

internal import SwiftUI

/// A small capsule pill that communicates a single status at a glance.
struct StatusPill: View {

    enum Kind {
        case syncing
        case synced(Date)
        case syncError(String, onRetry: () -> Void)
        case cleaning(current: Int, total: Int)
        case offline
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .syncing:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini).tint(Color.latte)
                Text("Syncing…")
            }
            .modifier(PillStyle(color: Color.latte))

        case .synced(let date):
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                Text("Updated \(date.relativeFormatted)")
            }
            .modifier(PillStyle(color: Color.roast))

        case .syncError(_, let onRetry):
            Button(action: onRetry) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Sync failed · Retry")
                }
                .modifier(PillStyle(color: .red.opacity(0.75)))
            }
            .buttonStyle(.borderless)

        case .cleaning(let cur, let tot):
            let pct = tot > 0 ? Int(Double(cur) / Double(tot) * 100) : 0
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise.circle.fill")
                Text("Cleaning \(pct)%")
            }
            .modifier(PillStyle(color: Color.roast))

        case .offline:
            HStack(spacing: 5) {
                Image(systemName: "wifi.slash")
                Text("Offline")
            }
            .modifier(PillStyle(color: Color.latte.opacity(0.6)))
        }
    }
}

// MARK: - Pill style

private struct PillStyle: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
