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

@Observable
final class FollowerSyncService {

    var state:     SyncState = .idle
    var followers: [String]  = []
    var following: [String]  = []

    private let api = InstagramAPIService()

    var hasValidSession: Bool { api.hasValidSession }

    /// Call after login to pick up freshly saved Keychain cookies.
    func reloadSession() { api.reloadSession() }

    @MainActor
    func startSync() async {
        guard api.hasValidSession else {
            state = .failed("No active session. Please log in first.")
            return
        }

        state = .validating

        do {
            // Validate session and retrieve the authenticated user's ID
            let user   = try await api.currentUser()
            let userId = user.pk

            // Fetch followers (with live progress updates)
            let followerNodes = try await api.fetchAllFollowers(userId: userId) { [weak self] current, total in
                self?.state = .fetchingFollowers(current: current, total: total)
            }

            // Fetch following (with live progress updates)
            let followingNodes = try await api.fetchAllFollowing(userId: userId) { [weak self] current, total in
                self?.state = .fetchingFollowing(current: current, total: total)
            }

            followers = followerNodes.map(\.username)
            following = followingNodes.map(\.username)
            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
