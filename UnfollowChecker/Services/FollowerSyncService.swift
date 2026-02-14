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

// MARK: - Cache model

private struct SyncCache: Codable {
    let followers:          [String]
    let following:          [String]
    let userPks:            [String: String]
    let requestedUsernames: [String]
    let date:               Date
}

// MARK: - Service

@Observable
final class FollowerSyncService {

    var state:              SyncState        = .idle
    var followers:          [String]         = []
    var following:          [String]         = []
    /// username → numeric pk (needed for unfollow API calls)
    var userPks:            [String: String] = [:]
    /// Following accounts where we have a pending (unapproved) follow request
    var requestedUsernames: [String]         = []
    /// Date of the last successful sync (live or from cache)
    private(set) var lastSyncDate: Date?

    var hasCachedData: Bool { FileManager.default.fileExists(atPath: cacheURL.path) }

    private let api = InstagramAPIService()

    var hasValidSession: Bool { api.hasValidSession }
    func reloadSession() { api.reloadSession() }

    // MARK: - Cache URL

    private var cacheURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("follower_sync_cache.json")
    }

    // MARK: - Restore from cache

    /// Loads previously saved sync data.  Sets state to `.done` if data is found.
    func restoreFromCache() {
        guard
            let data   = try? Data(contentsOf: cacheURL),
            let cached = try? JSONDecoder().decode(SyncCache.self, from: data)
        else { return }

        followers          = cached.followers
        following          = cached.following
        userPks            = cached.userPks
        requestedUsernames = cached.requestedUsernames
        lastSyncDate       = cached.date
        state              = .done
    }

    /// Deletes the local cache file (e.g. on logout).
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
        lastSyncDate = nil
    }

    // MARK: - Live sync

    @MainActor
    func startSync() async {
        guard api.hasValidSession else {
            state = .failed("No active session. Please log in first.")
            return
        }

        state = .validating

        do {
            let user   = try await api.currentUser()
            let userId = user.pk

            let followerNodes = try await api.fetchAllFollowers(userId: userId) { [weak self] current, total in
                self?.state = .fetchingFollowers(current: current, total: total)
            }

            let followingNodes = try await api.fetchAllFollowing(userId: userId) { [weak self] current, total in
                self?.state = .fetchingFollowing(current: current, total: total)
            }

            followers = followerNodes.map(\.username)
            following = followingNodes.map(\.username)

            userPks = Dictionary(
                uniqueKeysWithValues: followingNodes.compactMap { node -> (String, String)? in
                    guard let pk = node.pk ?? node.id, !pk.isEmpty else { return nil }
                    return (node.username, pk)
                }
            )

            requestedUsernames = followingNodes
                .filter { $0.requestedByViewer == true }
                .map(\.username)

            lastSyncDate = Date()
            saveToCache()
            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func saveToCache() {
        let cache = SyncCache(
            followers:          followers,
            following:          following,
            userPks:            userPks,
            requestedUsernames: requestedUsernames,
            date:               lastSyncDate ?? Date()
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
