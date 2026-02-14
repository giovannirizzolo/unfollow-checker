//
//  UnfollowService.swift
//  UnfollowChecker
//

import Foundation
import Observation

enum UnfollowState: Equatable {
    case idle
    case running(current: Int, total: Int)
    case done(succeeded: Int, failed: Int)
    case paused
    case failed(String)
}

@Observable
final class UnfollowService {

    var state:                UnfollowState = .idle
    /// Usernames that returned a non-retryable error (deleted accounts, etc.)
    var unavailableUsernames: [String]      = []

    private let api         = InstagramAPIService()
    private let rateLimiter = RateLimiter(maxPerHour: 60, delayRange: 8...15)
    private var isCancelled = false

    func pause() { isCancelled = true }

    // MARK: - Main entry point

    /// Unfollows each username in order, respecting rate limits.
    /// - Parameters:
    ///   - usernames: Ordered list of usernames to unfollow (requested accounts excluded upstream).
    ///   - pks:       username → Instagram numeric user ID map.
    ///   - store:     WhitelistStore used to mark successfully unfollowed users as done.
    @MainActor
    func startUnfollow(
        usernames: [String],
        pks: [String: String],
        store: WhitelistStore
    ) async {
        guard api.hasValidSession else {
            state = .failed("No active session. Please log in first.")
            return
        }

        isCancelled = false
        state = .running(current: 0, total: usernames.count)

        var succeeded = 0
        var failed    = 0

        for (index, username) in usernames.enumerated() {
            if isCancelled {
                state = .paused
                return
            }

            state = .running(current: index, total: usernames.count)

            guard let pk = pks[username], !pk.isEmpty else {
                // No pk available — skip silently (can't unfollow without the ID)
                failed += 1
                if !unavailableUsernames.contains(username) {
                    unavailableUsernames.append(username)
                }
                continue
            }

            do {
                try await rateLimiter.wait()

                if isCancelled {
                    state = .paused
                    return
                }

                try await api.unfollow(userId: pk)
                store.markDone(username)
                succeeded += 1

            } catch InstagramAPIError.rateLimited {
                // Hard rate limit hit — pause and let the user resume later
                state = .paused
                return

            } catch InstagramAPIError.unauthorized, InstagramAPIError.sessionExpired {
                state = .failed("Session expired. Please log in again.")
                return

            } catch {
                // User deleted, restricted, or other non-retryable error
                failed += 1
                if !unavailableUsernames.contains(username) {
                    unavailableUsernames.append(username)
                }
            }
        }

        state = .done(succeeded: succeeded, failed: failed)
    }
}
