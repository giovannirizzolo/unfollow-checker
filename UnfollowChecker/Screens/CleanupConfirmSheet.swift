//
//  CleanupConfirmSheet.swift
//  UnfollowChecker
//

internal import SwiftUI

/// Confirmation sheet shown before starting a bulk-unfollow cleanup.
struct CleanupConfirmSheet: View {
    let cleanupCount:     Int
    let whitelistCount:   Int
    let hasActiveList:    Bool
    let onStart:          () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()

                    // Count badge
                    VStack(spacing: 8) {
                        Text("💀")
                            .font(.system(size: 48))
                        Text("\(cleanupCount)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.espresso)
                        Text("accounts to unfollow")
                            .font(.subheadline)
                            .foregroundStyle(Color.latte)
                    }

                    // Whitelist info
                    if hasActiveList {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color.latte)
                            Text("\(whitelistCount) whitelisted account\(whitelistCount == 1 ? "" : "s") will be skipped")
                                .font(.subheadline)
                                .foregroundStyle(Color.roast)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.latte.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Rate limit info
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(Color.latte)
                        Text("Up to 60 per hour · 8–15 s between each")
                            .font(.caption)
                            .foregroundStyle(Color.latte)
                    }

                    Spacer()

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            onStart()
                        } label: {
                            Text("Start cleanup")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.roast)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.borderless)

                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                        .foregroundStyle(Color.latte)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Clean up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CleanupConfirmSheet(
        cleanupCount: 42,
        whitelistCount: 5,
        hasActiveList: true,
        onStart: {}
    )
}
