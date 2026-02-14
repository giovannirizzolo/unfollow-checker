//
//  FollowerSyncService.swift
//  UnfollowChecker
//

import Foundation
import Observation

enum SyncState: Equatable {
    case idle
    case validating
    case fetchingFollowers(current: Int, total: Int)
    case fetchingFollowing(current: Int, total: Int)
    case done
    case failed(String)
}

// MARK: - Persisted cache model (private)

private struct PersistedCache: Codable {
    var metadata:  SyncMetadata
    var followers: [CachedUser]
    var following: [CachedUser]
}

// MARK: - Service

@Observable
final class FollowerSyncService {

    // MARK: - Published state

    var state:              SyncState        = .idle
    var followers:          [String]         = []
    var following:          [String]         = []
    /// username → numeric pk (needed for unfollow API calls)
    var userPks:            [String: String] = [:]
    /// Following accounts where we have a pending (unapproved) follow request
    var requestedUsernames: [String]         = []
    /// Date of the last sync (partial or full)
    private(set) var lastSyncDate:      Date?
    /// Date of the last full sync (used for the 7-day schedule)
    private(set) var lastFullSyncDate:  Date?
    /// `true` when the most recently completed sync was a full sync.
    /// Used by the UI to decide whether to reset done-state.
    private(set) var lastSyncWasFull:   Bool = false

    // MARK: - Configuration

    /// Pages fetched in partial mode (50 users/page → 250 users with default 5 pages).
    private let partialPageCount: Int           = 5
    /// Interval between mandatory full syncs.
    private let fullSyncInterval: TimeInterval  = 7 * 24 * 3600
    /// Fraction of count difference that auto-promotes partial → full sync.
    private let divergenceThreshold: Double     = 0.20

    // MARK: - Dependencies

    private let api = InstagramAPIService()

    var hasValidSession: Bool { api.hasValidSession }
    func reloadSession() { api.reloadSession() }

    // MARK: - Derived state

    /// Which sync mode will be used when `startSync()` is called next.
    var nextSyncMode: SyncMode {
        guard let lastFull = lastFullSyncDate else { return .full }
        return Date().timeIntervalSince(lastFull) >= fullSyncInterval ? .full : .partial
    }

    var hasCachedData: Bool {
        FileManager.default.fileExists(atPath: cacheURL.path)
    }

    // MARK: - Cache URL (per-account namespacing)

    private var cacheURL: URL {
        let accountId = KeychainService.load(for: .userId) ?? "default"
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sync_cache_\(accountId).json")
    }

    // MARK: - Restore from cache

    /// Loads previously saved sync data. Sets state to `.done` if data is found.
    func restoreFromCache() {
        guard let cache = loadRawCache() else { return }
        applyCache(cache)
        state = .done
    }

    /// Deletes the local cache file (e.g. on logout).
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
        lastSyncDate     = nil
        lastFullSyncDate = nil
    }

    // MARK: - Sync entry points

    /// Starts either a partial or full sync based on the 7-day schedule.
    @MainActor
    func startSync() async {
        switch nextSyncMode {
        case .full:    await performFullSync()
        case .partial: await performPartialSync()
        }
    }

    /// Forces a full sync regardless of the schedule.
    @MainActor
    func startFullSync() async {
        await performFullSync()
    }

    // MARK: - Partial sync

    @MainActor
    private func performPartialSync() async {
        guard api.hasValidSession else {
            state = .failed("No active session. Please log in first.")
            return
        }

        state = .validating

        do {
            let user   = try await api.currentUser()
            let userId = user.pk

            // Build known-ID sets from the existing cache for the early-stop heuristic.
            let existing        = loadRawCache()
            let knownFollowers  = Set(existing?.followers.map(\.username) ?? [])
            let knownFollowing  = Set(existing?.following.map(\.username) ?? [])

            let followerResult = try await api.fetchFollowers(
                userId:   userId,
                maxPages: partialPageCount,
                knownIDs: knownFollowers
            ) { [weak self] current, total in
                self?.state = .fetchingFollowers(current: current, total: total)
            }

            let followingResult = try await api.fetchFollowing(
                userId:   userId,
                maxPages: partialPageCount,
                knownIDs: knownFollowing
            ) { [weak self] current, total in
                self?.state = .fetchingFollowing(current: current, total: total)
            }

            // If the API-reported count has diverged >20% from what the API reported last time,
            // promote to a full sync. We compare against the stored API count (not the cache
            // array size, which is smaller in partial mode).
            if let existing,
               shouldPromoteToFull(apiCount: followerResult.apiTotalCount,  lastAPICount: existing.metadata.followerAPICount)
               || shouldPromoteToFull(apiCount: followingResult.apiTotalCount, lastAPICount: existing.metadata.followingAPICount) {
                await performFullSync()
                return
            }

            // Merge: new nodes are added/updated; cached nodes not in this fetch are preserved.
            let mergedFollowers: [CachedUser]
            let mergedFollowing: [CachedUser]
            if let existing {
                mergedFollowers = mergeUsers(existing: existing.followers, fetched: followerResult.nodes)
                mergedFollowing = mergeUsers(existing: existing.following, fetched: followingResult.nodes)
            } else {
                mergedFollowers = toCachedUsers(followerResult.nodes)
                mergedFollowing = toCachedUsers(followingResult.nodes)
            }

            let now      = Date()
            let metadata = SyncMetadata(
                accountId:         userId,
                lastFullSync:      existing?.metadata.lastFullSync ?? now,
                lastPartialSync:   now,
                followerAPICount:  followerResult.apiTotalCount,
                followingAPICount: followingResult.apiTotalCount
            )

            let newCache = PersistedCache(metadata: metadata, followers: mergedFollowers, following: mergedFollowing)
            save(cache: newCache)
            applyCache(newCache)
            lastSyncDate    = now
            lastSyncWasFull = false
            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Full sync

    @MainActor
    private func performFullSync() async {
        guard api.hasValidSession else {
            state = .failed("No active session. Please log in first.")
            return
        }

        state = .validating

        do {
            let user   = try await api.currentUser()
            let userId = user.pk

            let followerResult = try await api.fetchFollowers(
                userId: userId
            ) { [weak self] current, total in
                self?.state = .fetchingFollowers(current: current, total: total)
            }

            let followingResult = try await api.fetchFollowing(
                userId: userId
            ) { [weak self] current, total in
                self?.state = .fetchingFollowing(current: current, total: total)
            }

            let now      = Date()
            let metadata = SyncMetadata(
                accountId:         userId,
                lastFullSync:      now,
                lastPartialSync:   nil,
                followerAPICount:  followerResult.apiTotalCount,
                followingAPICount: followingResult.apiTotalCount
            )

            let newCache = PersistedCache(
                metadata:  metadata,
                followers: toCachedUsers(followerResult.nodes),
                following: toCachedUsers(followingResult.nodes)
            )
            save(cache: newCache)
            applyCache(newCache)
            lastSyncDate     = now
            lastFullSyncDate = now
            lastSyncWasFull  = true
            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func applyCache(_ cache: PersistedCache) {
        followers = cache.followers.map(\.username)
        following = cache.following.map(\.username)
        userPks   = Dictionary(
            uniqueKeysWithValues: cache.following.compactMap { u -> (String, String)? in
                guard let pk = u.pk, !pk.isEmpty else { return nil }
                return (u.username, pk)
            }
        )
        requestedUsernames = cache.following
            .filter { $0.requestedByViewer }
            .map(\.username)
        lastFullSyncDate = cache.metadata.lastFullSync
        lastSyncDate     = cache.metadata.lastPartialSync ?? cache.metadata.lastFullSync
    }

    private func shouldPromoteToFull(apiCount: Int, lastAPICount: Int) -> Bool {
        guard lastAPICount > 0, apiCount > 0 else { return false }
        let ratio = abs(Double(apiCount - lastAPICount)) / Double(lastAPICount)
        return ratio > divergenceThreshold
    }

    /// Merge fetched nodes into the existing cache list.
    /// Fetched nodes overwrite cached entries with the same username;
    /// cached entries not present in the fetch are preserved unchanged.
    private func mergeUsers(existing: [CachedUser], fetched: [EdgeNode]) -> [CachedUser] {
        var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.username, $0) })
        for node in fetched {
            dict[node.username] = CachedUser(
                username:          node.username,
                pk:                node.pk ?? node.id,
                requestedByViewer: node.requestedByViewer ?? false
            )
        }
        return dict.values.sorted { $0.username < $1.username }
    }

    private func toCachedUsers(_ nodes: [EdgeNode]) -> [CachedUser] {
        nodes.map {
            CachedUser(
                username:          $0.username,
                pk:                $0.pk ?? $0.id,
                requestedByViewer: $0.requestedByViewer ?? false
            )
        }
    }

    private func loadRawCache() -> PersistedCache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(PersistedCache.self, from: data)
    }

    private func save(cache: PersistedCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
