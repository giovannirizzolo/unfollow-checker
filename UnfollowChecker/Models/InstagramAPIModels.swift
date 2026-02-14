//
//  InstagramAPIModels.swift
//  UnfollowChecker
//

import Foundation

// MARK: - Errors

enum InstagramAPIError: Error, LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case challengeRequired(challengeUrl: String)
    case networkError(Error)
    case invalidResponse
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session invalid or expired. Please log in again."
        case .rateLimited(let t):
            return "Rate limited by Instagram. Retry in \(Int(t / 60)) minutes."
        case .challengeRequired:
            return "Instagram requires a security check. Please complete it and try again."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidResponse:
            return "Unexpected response from Instagram."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        }
    }
}

// MARK: - Current User

struct CurrentUserResponse: Decodable {
    let user: APIUser
}

struct APIUser: Decodable {
    let pk: String
    let username: String
    let fullName: String
    let profilePicUrl: String?
    let isPrivate: Bool
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case pk, username
        case fullName      = "full_name"
        case profilePicUrl = "profile_pic_url"
        case isPrivate     = "is_private"
        case isVerified    = "is_verified"
    }
}

// MARK: - GraphQL Followers / Following

struct FollowGraphQLResponse: Decodable {
    let data: FollowGraphQLData
}

struct FollowGraphQLData: Decodable {
    let user: FollowUserWrapper
}

struct FollowUserWrapper: Decodable {
    let edgeFollowedBy: EdgeConnection?  // followers
    let edgeFollow:     EdgeConnection?  // following

    enum CodingKeys: String, CodingKey {
        case edgeFollowedBy = "edge_followed_by"
        case edgeFollow     = "edge_follow"
    }
}

struct EdgeConnection: Decodable {
    let count:    Int
    let pageInfo: PageInfo
    let edges:    [Edge]

    enum CodingKeys: String, CodingKey {
        case count
        case pageInfo = "page_info"
        case edges
    }
}

struct Edge: Decodable {
    let node: EdgeNode
}

struct EdgeNode: Decodable {
    let pk:                String?
    let id:                String?
    let username:          String
    let fullName:          String?
    let profilePicUrl:     String?
    let isPrivate:         Bool?
    let isVerified:        Bool?
    let requestedByViewer: Bool?   // true when we sent a follow request they haven't accepted

    enum CodingKeys: String, CodingKey {
        case pk, id, username
        case fullName          = "full_name"
        case profilePicUrl     = "profile_pic_url"
        case isPrivate         = "is_private"
        case isVerified        = "is_verified"
        case requestedByViewer = "requested_by_viewer"
    }
}

struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor:   String?

    enum CodingKeys: String, CodingKey {
        case hasNextPage = "has_next_page"
        case endCursor   = "end_cursor"
    }
}

// MARK: - Fetch result

struct FetchResult {
    /// Nodes returned — may be partial if early-stopped or maxPages was hit.
    let nodes:         [EdgeNode]
    /// `true` when we reached the final page; `false` when stopped early.
    let fetchedAll:    Bool
    /// Total count reported by the API (`count` field on the connection).
    let apiTotalCount: Int
}
