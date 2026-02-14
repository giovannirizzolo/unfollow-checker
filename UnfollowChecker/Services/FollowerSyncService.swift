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

    var state:              SyncState       = .idle
    var followers:          [String]        = []
    var following:          [String]        = []
    /// username → numeric pk (needed for unfollow API calls)
    var userPks:            [String: String] = [:]
    /// Following accounts where we have a pending (unapproved) follow request
    var requestedUsernames: [String]        = []

    private let api = InstagramAPIService()

    var hasValidSession: Bool { api.hasValidSession }

    func reloadSession() { api.reloadSession() }

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

            // Build pk lookup from all following nodes (use pk, fall back to id)
            userPks = Dictionary(
                uniqueKeysWithValues: followingNodes.compactMap { node -> (String, String)? in
                    guard let pk = node.pk ?? node.id, !pk.isEmpty else { return nil }
                    return (node.username, pk)
                }
            )

            requestedUsernames = followingNodes
                .filter { $0.requestedByViewer == true }
                .map(\.username)

            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
