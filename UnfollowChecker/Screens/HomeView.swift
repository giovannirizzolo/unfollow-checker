//
//  HomeView.swift
//  UnfollowChecker
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

    // Results
    @State private var notFollowingBack: [String] = []
    @State private var store = WhitelistStore()

    // Services
    @State private var syncService     = FollowerSyncService()
    @State private var unfollowService = UnfollowService()

    // Navigation
    @State private var selectedTab = 0
    @State private var showLogin   = false

    // Modals
    @State private var showCleanupConfirm   = false
    @State private var showCleanupProgress  = false
    @State private var showOnboarding       = false
    @AppStorage("hasSeenSafetyOnboarding") private var hasSeenOnboarding = false

    // Alerts
    @State private var syncError: String?
    @State private var showWhitelistWarning = false

    // Auto-sync throttle (UI-only)
    @State private var lastAutoSync: Date?
    private let autoSyncInterval: TimeInterval = 15 * 60

    var cleanupUsers: [String] {
        notFollowingBack.filter { !store.isWhitelisted($0) && !store.isDone($0) }
    }
    var whitelistedCount: Int { notFollowingBack.filter { store.isWhitelisted($0) }.count }
    var doneCount: Int        { notFollowingBack.filter { store.isDone($0) }.count }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ListTab(
                notFollowingBack:   notFollowingBack,
                requestedUsernames: syncService.requestedUsernames,
                userPks:            syncService.userPks
            )
            .tabItem { Label("List", systemImage: "list.bullet") }
            .tag(1)

            WhitelistView(notFollowingBack: notFollowingBack)
                .tabItem { Label("Whitelist", systemImage: "star.fill") }
                .tag(2)
                .badge(whitelistedCount)
        }
        .tint(Color.roast)
        .environment(store)
        .environment(unfollowService)
        // Global cleanup progress banner across all tabs
        .safeAreaInset(edge: .bottom) {
            ProgressBanner(showProgressSheet: $showCleanupProgress)
                .environment(unfollowService)
        }
        .sheet(isPresented: $showCleanupProgress) {
            CleanupProgressView()
                .environment(unfollowService)
        }
    }

    // MARK: - Home tab

    private var homeTab: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        counterCard
                        statusRow
                        cleanupSection
                        apiCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Unfollow Checker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.latte)
                    }
                }
            }
            .task {
                syncService.restoreFromCache()
                triggerAutoSyncIfNeeded()
            }
            .fullScreenCover(isPresented: $showLogin) {
                LoginWebView {
                    showLogin = false
                    syncService.reloadSession()
                    Task { await syncService.startSync() }
                }
            }
            .sheet(isPresented: $showOnboarding) {
                SafetyOnboardingView()
            }
            .sheet(isPresented: $showCleanupConfirm) {
                CleanupConfirmSheet(
                    cleanupCount:   cleanupUsers.count,
                    whitelistCount: whitelistedCount,
                    hasActiveList:  store.activeID != nil,
                    onStart:        startUnfollowNow
                )
            }
            .onChange(of: syncService.state) { _, newState in
                if case .done = newState {
                    applyAPISync()
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
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
                    showCleanupConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have a whitelist but it's not currently enabled. Every user who doesn't follow you back will be unfollowed.")
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

    // MARK: - Status pills row

    @ViewBuilder
    private var statusRow: some View {
        let pills = activePills
        if !pills.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pills.indices, id: \.self) { i in
                        pills[i]
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }

    private var activePills: [AnyView] {
        var result: [AnyView] = []

        // Sync status
        switch syncService.state {
        case .validating, .fetchingFollowers, .fetchingFollowing:
            result.append(AnyView(StatusPill(kind: .syncing)))
        case .done:
            if let date = syncService.lastSyncDate {
                result.append(AnyView(StatusPill(kind: .synced(date))))
            }
        case .failed(let msg):
            result.append(AnyView(StatusPill(kind: .syncError(msg) {
                Task { await syncService.startSync() }
            })))
        default:
            if let date = syncService.lastSyncDate {
                result.append(AnyView(StatusPill(kind: .synced(date))))
            }
        }

        // Cleanup status
        if case .running(let cur, let tot) = unfollowService.state {
            result.append(AnyView(StatusPill(kind: .cleaning(current: cur, total: tot))))
        }

        return result
    }

    // MARK: - Cleanup section

    @ViewBuilder
    private var cleanupSection: some View {
        VStack(spacing: 12) {
            switch unfollowService.state {

            // ── Idle / failed: primary action + view list ──────────────
            case .idle, .failed:
                if syncService.lastSyncDate != nil && !cleanupUsers.isEmpty {
                    if case .failed(let msg) = unfollowService.state {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Primary: Clean up
                    Button { triggerCleanup() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill.xmark")
                            Text("Clean up (\(cleanupUsers.count))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.roast)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.borderless)

                    // Secondary: View list
                    Button { selectedTab = 1 } label: {
                        Text("View list")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.latte.opacity(0.15))
                            .foregroundStyle(Color.roast)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.borderless)
                }

            // ── Running: banner handled globally; show stop inline ─────
            case .running(let cur, let tot):
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Cleaning up…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.espresso)
                        Spacer()
                        Text("\(cur) / \(tot)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.latte)
                    }

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

                    HStack(spacing: 8) {
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

                        Button { showCleanupProgress = true } label: {
                            Label("Details", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.roast.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.roast)
                    }
                }
                .padding(16)
                .background(Color.foam)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // ── Paused ────────────────────────────────────────────────
            case .paused:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(Color.latte)
                        Text("Cleanup paused")
                            .font(.subheadline)
                            .foregroundStyle(Color.espresso)
                    }
                    HStack(spacing: 8) {
                        Button { triggerCleanup() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.roast.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.roast)

                        Button { unfollowService.state = .idle } label: {
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
                .padding(16)
                .background(Color.foam)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // ── Done: summary ─────────────────────────────────────────
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
                    Button { unfollowService.state = .idle } label: {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.latte.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.latte)
                }
                .padding(16)
                .background(Color.foam)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func doneSummary(succeeded: Int, failed: Int) -> String {
        var parts: [String] = []
        if succeeded > 0 { parts.append("Unfollowed \(succeeded)") }
        if failed    > 0 { parts.append("\(failed) unavailable") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Cleanup helpers

    private func triggerCleanup() {
        if !store.whitelists.isEmpty && store.activeID == nil {
            showWhitelistWarning = true
        } else {
            showCleanupConfirm = true
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

    // MARK: - Auto-sync

    private func triggerAutoSyncIfNeeded() {
        guard syncService.hasValidSession,
              case .idle = syncService.state else { return }
        if let last = lastAutoSync, Date().timeIntervalSince(last) < autoSyncInterval { return }
        lastAutoSync = Date()
        Task { await syncService.startSync() }
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
        // Only reset done-state after a full sync. A partial sync doesn't
        // fetch all pages, so unfollowed users may still be in the following
        // cache. Resetting done markers here would make them reappear in the
        // cleanup queue even though they were already processed.
        if syncService.lastSyncWasFull {
            store.resetDone()
        }
        store.prune(keeping: Set(notFollowingBack))
        store.recordUpdate()
    }

    // MARK: - Import (kept for future re-enable, not shown in UI)

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.espresso)
        }
        .padding(16)
        .background(Color.foam)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview { HomeView() }
