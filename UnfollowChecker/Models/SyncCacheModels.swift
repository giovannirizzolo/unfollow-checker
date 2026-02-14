//
//  SyncCacheModels.swift
//  UnfollowChecker
//

import Foundation

/// A single user entry stored in the local sync cache.
struct CachedUser: Codable, Hashable {
    let username: String
    let pk: String?
    let requestedByViewer: Bool
}

/// Metadata associated with a persisted sync, stored alongside the user lists.
struct SyncMetadata: Codable {
    /// `ds_user_id` — used for per-account file namespacing.
    let accountId: String
    /// Last time we fetched ALL pages (full sync).
    let lastFullSync: Date
    /// Last time we fetched the first N pages only (partial sync).
    var lastPartialSync: Date?
    /// Total follower count reported by the API at the last full sync.
    let followerAPICount: Int
    /// Total following count reported by the API at the last full sync.
    let followingAPICount: Int
}

/// Which kind of sync is scheduled or in progress.
enum SyncMode: Equatable {
    /// Fetch only the first N pages and merge results (no removals from cache).
    case partial
    /// Fetch all pages and replace the cache entirely.
    case full
}
