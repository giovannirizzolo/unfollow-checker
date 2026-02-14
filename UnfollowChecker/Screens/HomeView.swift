//
//  HomeView.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

internal import SwiftUI
import UniformTypeIdentifiers

// MARK: - Coffee colour palette

extension Color {
    static let espresso = Color(red: 0.28, green: 0.15, blue: 0.05)
    static let roast    = Color(red: 0.52, green: 0.30, blue: 0.12)
    static let latte    = Color(red: 0.76, green: 0.58, blue: 0.38)
    static let cream    = Color(red: 0.97, green: 0.93, blue: 0.87)
    static let foam     = Color(red: 0.99, green: 0.97, blue: 0.94)
}

extension Date {
    var relativeFormatted: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Root view

struct HomeView: View {

    // Import state (kept for future re-enable)
    @State private var followersData: Data?
    @State private var followingData: Data?
    @State private var followersStatus: ImportStatus = .idle
    @State private var followingStatus: ImportStatus = .idle
    @State private var showImporter = false
    @State private var expecting: Expecting = .followers

    // Results
    @State private var notFollowingBack: [String] = []
    @State private var store = WhitelistStore()

    // Instagram API
    @State private var syncService     = FollowerSyncService()
    @State private var unfollowService = UnfollowService()
    @State private var showLogin       = false
    @State private var syncError: String?

    // Unfollow gate
    @State private var showWhitelistWarning = false

    var cleanupUsers: [String] {
        notFollowingBack.filter { !store.isWhitelisted($0) && !store.isDone($0) }
    }
    var whitelistedCount: Int { notFollowingBack.filter { store.isWhitelisted($0) }.count }
    var doneCount: Int        { notFollowingBack.filter { store.isDone($0) }.count }

    enum Expecting { case followers, following }

    enum ImportStatus: Equatable {
        case idle, importing
        case success(String), error(String)
    }

    var body: some View {
        TabView {
            homeTab
                .tabItem { Label("Home", systemImage: "house.fill") }

            ListTab(
                notFollowingBack:   notFollowingBack,
                requestedUsernames: syncService.requestedUsernames,
                userPks:            syncService.userPks
            )
            .tabItem { Label("List", systemImage: "list.bullet") }

            WhitelistView(notFollowingBack: notFollowingBack)
                .tabItem { Label("Whitelist", systemImage: "star.fill") }
                .badge(whitelistedCount)
        }
        .tint(Color.roast)
        .environment(store)
        .environment(unfollowService)
    }

    // MARK: - Home tab

    private var homeTab: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        counterCard
                        unfollowCard
                        apiCard
                        // importCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Unfollow Checker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                syncService.restoreFromCache()
            }
            .fullScreenCover(isPresented: $showLogin) {
                LoginWebView {
                    showLogin = false
                    syncService.reloadSession()
                    Task { await syncService.startSync() }
                }
            }
            .onChange(of: syncService.state) { _, newState in
                if case .done = newState { applyAPISync() }
                if case .failed(let msg) = newState { syncError = msg }
            }
            .alert("Sync failed", isPresented: Binding(
                get: { syncError != nil },
                set: { if !$0 { syncError = nil } }
            )) {
                Button("OK") { syncError = nil }
            } message: {
                Text(syncError ?? "")
            }
            .alert("Whitelist not active", isPresented: $showWhitelistWarning) {
                Button("Unfollow all \(cleanupUsers.count)", role: .destructive) {
                    startUnfollowNow()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have a whitelist but it's not currently enabled. Every user who doesn't follow you back will be unfollowed. Go to the Whitelist tab to activate protection first.")
            }
        }
    }

    // MARK: - Counter card

    private var counterCard: some View {
        VStack(spacing: 8) {
            if syncService.lastSyncDate != nil {
                HStack(spacing: 10) {
                    Text("💀")
                        .font(.title2)
                    Text("\(notFollowingBack.count)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.espresso)
                }
                Text("don't follow you back")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.latte)

                if whitelistedCount > 0 || doneCount > 0 {
                    HStack(spacing: 16) {
                        if whitelistedCount > 0 {
                            Label("\(whitelistedCount) whitelisted", systemImage: "star.fill")
                        }
                        if doneCount > 0 {
                            Label("\(doneCount) done", systemImage: "checkmark.circle.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.latte)
                    .padding(.top, 2)
                }

                if let date = syncService.lastSyncDate {
                    Text("Synced \(date.relativeFormatted)")
                        .font(.caption2)
                        .foregroundStyle(Color.latte.opacity(0.7))
                        .padding(.top, 2)
                }
            } else {
                Text("💀")
                    .font(.system(size: 40))
                    .opacity(0.4)
                    .padding(.bottom, 4)
                Text("No data yet")
                    .font(.headline)
                    .foregroundStyle(Color.latte)
                Text("Connect Instagram to see who doesn't follow you back")
                    .font(.caption)
                    .foregroundStyle(Color.latte.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.foam)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Unfollow card

    private var unfollowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch unfollowService.state {

            // ── Idle / failed: primary action button ──────────────────────────
            case .idle, .failed:
                if syncService.lastSyncDate == nil {
                    // No sync yet — can't unfollow
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.latte)
                        Text("Sync your Instagram account first")
                            .font(.caption)
                            .foregroundStyle(Color.latte)
                    }
                } else if cleanupUsers.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.roast)
                        Text("No users to unfollow right now")
                            .font(.caption)
                            .foregroundStyle(Color.latte)
                    }
                } else {
                    if case .failed(let msg) = unfollowService.state {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button { triggerUnfollow() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill.xmark")
                            Text("Unfollow All (\(cleanupUsers.count))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.roast)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.borderless)
                }

            // ── Running: fancy progress widget ────────────────────────────────
            case .running(let cur, let tot):
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Unfollowing…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.espresso)
                        Spacer()
                        Text("\(cur) / \(tot)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.latte)
                    }

                    // Fancy gradient progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.latte.opacity(0.18))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.latte, Color.roast],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: tot > 0
                                        ? max(20, geo.size.width * CGFloat(cur) / CGFloat(tot))
                                        : 0,
                                    height: 10
                                )
                                .animation(.easeInOut(duration: 0.35), value: cur)
                        }
                    }
                    .frame(height: 10)

                    Button {
                        unfollowService.pause()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.latte.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.roast)
                }

            // ── Paused ────────────────────────────────────────────────────────
            case .paused:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(Color.latte)
                        Text("Unfollow paused")
                            .font(.subheadline)
                            .foregroundStyle(Color.espresso)
                    }
                    HStack(spacing: 8) {
                        Button { triggerUnfollow() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.roast.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.roast)

                        Button {
                            unfollowService.state = .idle
                        } label: {
                            Text("Dismiss")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.latte.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.latte)
                    }
                }

            // ── Done: summary ─────────────────────────────────────────────────
            case .done(let succeeded, let failed):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.roast)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Done!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.espresso)
                            Text(doneSummary(succeeded: succeeded, failed: failed))
                                .font(.caption)
                                .foregroundStyle(Color.latte)
                        }
                    }
                    Button {
                        unfollowService.state = .idle
                    } label: {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.latte.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.latte)
                }
            }
        }
        .padding(16)
        .background(Color.foam)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func doneSummary(succeeded: Int, failed: Int) -> String {
        var parts: [String] = []
        if succeeded > 0 { parts.append("Unfollowed \(succeeded)") }
        if failed    > 0 { parts.append("\(failed) unavailable") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Unfollow helpers

    private func triggerUnfollow() {
        // Warn if user has whitelists but none is currently active
        if !store.whitelists.isEmpty && store.activeID == nil {
            showWhitelistWarning = true
        } else {
            startUnfollowNow()
        }
    }

    private func startUnfollowNow() {
        let targets = cleanupUsers.filter { !syncService.requestedUsernames.contains($0) }
        Task {
            await unfollowService.startUnfollow(
                usernames: targets,
                pks:       syncService.userPks,
                store:     store
            )
        }
    }

    // MARK: - Instagram API card

    private var apiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("📸")
                Text("Instagram connect")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.espresso)
            }

            switch syncService.state {
            case .idle:
                if syncService.hasValidSession {
                    syncButton(label: "Sync followers", icon: "arrow.clockwise") {
                        Task { await syncService.startSync() }
                    }
                } else {
                    syncButton(label: "Connect Instagram", icon: "person.crop.circle.badge.plus") {
                        showLogin = true
                    }
                }

            case .validating:
                progressRow(label: "Validating session…", current: nil, total: nil)

            case .fetchingFollowers(let cur, let tot):
                progressRow(label: "Fetching followers", current: cur, total: tot)

            case .fetchingFollowing(let cur, let tot):
                progressRow(label: "Fetching following", current: cur, total: tot)

            case .done:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.roast)
                        VStack(alignment: .leading, spacing: 2) {
                            if let date = syncService.lastSyncDate {
                                Text("Synced \(date.relativeFormatted)")
                                    .font(.caption).foregroundStyle(Color.roast)
                            } else {
                                Text("Data loaded").font(.caption).foregroundStyle(Color.roast)
                            }
                            let modeLabel = syncService.nextSyncMode == .full
                                ? "Next: full sync"
                                : "Next: partial sync"
                            Text(modeLabel)
                                .font(.caption2).foregroundStyle(Color.latte.opacity(0.7))
                        }
                    }
                    if syncService.hasValidSession {
                        HStack(spacing: 8) {
                            syncButton(label: "Sync", icon: "arrow.clockwise") {
                                Task { await syncService.startSync() }
                            }
                            if syncService.nextSyncMode == .partial {
                                syncButton(label: "Full sync", icon: "arrow.clockwise.circle") {
                                    Task { await syncService.startFullSync() }
                                }
                            }
                        }
                    }
                }

            case .failed:
                syncButton(label: "Retry sync", icon: "arrow.clockwise") {
                    Task { await syncService.startSync() }
                }
            }
        }
        .padding(16)
        .background(Color.foam)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func syncButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.roast.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color.roast)
    }

    @ViewBuilder
    private func progressRow(label: String, current: Int?, total: Int?) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini).tint(Color.roast)
            if let current, let total, total > 0 {
                Text("\(label) \(current)/\(total)")
                    .font(.caption).foregroundStyle(Color.latte)
            } else {
                Text(label).font(.caption).foregroundStyle(Color.latte)
            }
        }
    }

    // MARK: - Apply API sync result

    private func applyAPISync() {
        notFollowingBack = InstagramExportParser.computeNotFollowingBack(
            followers: syncService.followers,
            following: syncService.following
        )
        store.resetDone()
        store.prune(keeping: Set(notFollowingBack))
        store.recordUpdate()
    }

    // MARK: - Import column (kept for future re-enable)

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.espresso)
            HStack(spacing: 12) {
                importColumn(label: "Followers", type: .followers, status: followersStatus)
                importColumn(label: "Following", type: .following, status: followingStatus)
            }
        }
        .padding(16)
        .background(Color.foam)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func importColumn(label: String, type: Expecting, status: ImportStatus) -> some View {
        VStack(spacing: 6) {
            Button {
                expecting = type
                showImporter = true
            } label: {
                Label(label, systemImage: type == .followers ? "person.2.fill" : "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.latte.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.roast)
            .disabled(status == .importing)

            statusLabel(for: status)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statusLabel(for status: ImportStatus) -> some View {
        switch status {
        case .idle:
            Text("No file selected")
                .font(.caption)
                .foregroundStyle(Color.latte.opacity(0.8))
        case .importing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini).tint(Color.roast)
                Text("Reading…").font(.caption).foregroundStyle(Color.latte)
            }
        case .success(let info):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.roast)
                Text(info)
            }
            .font(.caption).foregroundStyle(Color.roast)
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message).lineLimit(2)
            }
            .font(.caption).foregroundStyle(.red)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>, type: Expecting) async {
        setStatus(.importing, for: type)
        do {
            let urls = try result.get()
            guard let url = urls.first else { setStatus(.idle, for: type); return }
            guard url.startAccessingSecurityScopedResource() else {
                setStatus(.error("Permission denied accessing file"), for: type)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let usernames = try InstagramExportParser.parseUsernames(from: data)
            let countLabel = type == .followers
                ? "\(usernames.count) followers"
                : "\(usernames.count) following"
            if type == .followers { followersData = data } else { followingData = data }
            setStatus(.success(countLabel), for: type)
            do { try recompute() } catch { setStatus(.error(error.localizedDescription), for: type) }
        } catch {
            setStatus(.error("Import failed: \(error.localizedDescription)"), for: type)
        }
    }

    private func setStatus(_ status: ImportStatus, for type: Expecting) {
        if type == .followers { followersStatus = status } else { followingStatus = status }
    }

    private func recompute() throws {
        guard let followersData, let followingData else { return }
        let followers = try InstagramExportParser.parseUsernames(from: followersData)
        let following = try InstagramExportParser.parseUsernames(from: followingData)
        notFollowingBack = InstagramExportParser.computeNotFollowingBack(
            followers: followers,
            following: following
        )
        store.resetDone()
        store.prune(keeping: Set(notFollowingBack))
        store.recordUpdate()
    }
}

#Preview { HomeView() }
