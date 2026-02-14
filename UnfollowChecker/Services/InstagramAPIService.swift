//
//  InstagramAPIService.swift
//  UnfollowChecker
//

import Foundation

final class InstagramAPIService {

    private let urlSession: URLSession
    private let rateLimiter = RateLimiter()

    // Cached from Keychain
    private var sessionId: String?
    private var csrfToken: String?
    private var userId:    String?
    private var igDid:     String?
    private var mid:       String?

    var hasValidSession: Bool { sessionId != nil && csrfToken != nil }

    init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        urlSession = URLSession(configuration: config)
        loadCookies()
    }

    func reloadSession() { loadCookies() }

    private func loadCookies() {
        sessionId = KeychainService.load(for: .sessionId)
        csrfToken = KeychainService.load(for: .csrfToken)
        userId    = KeychainService.load(for: .userId)
        igDid     = KeychainService.load(for: .igDid)
        mid       = KeychainService.load(for: .mid)
    }

    // MARK: - Current User

    func currentUser() async throws -> APIUser {
        guard let url = URL(string: "https://i.instagram.com/api/v1/accounts/current_user/?edit=true") else {
            throw InstagramAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        try applyHeaders(to: &request)
        try await rateLimiter.wait()
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(CurrentUserResponse.self, from: data).user
    }

    // MARK: - Followers / Following

    /// Fetch followers, optionally stopping after `maxPages` pages.
    /// Pass `knownIDs` to enable the early-stop heuristic (stops after 2
    /// consecutive fully-known pages, starting from page 3 onwards).
    func fetchFollowers(
        userId:     String,
        maxPages:   Int?          = nil,
        knownIDs:   Set<String>   = [],
        onProgress: @MainActor @escaping (Int, Int) -> Void
    ) async throws -> FetchResult {
        try await fetchAll(
            queryHash: "c76146de99bb02f6415203be841dd25a",
            userId:    userId,
            edgeType:  .followers,
            maxPages:  maxPages,
            knownIDs:  knownIDs,
            onProgress: onProgress
        )
    }

    /// Fetch following, optionally stopping after `maxPages` pages.
    func fetchFollowing(
        userId:     String,
        maxPages:   Int?          = nil,
        knownIDs:   Set<String>   = [],
        onProgress: @MainActor @escaping (Int, Int) -> Void
    ) async throws -> FetchResult {
        try await fetchAll(
            queryHash: "d04b0a864b4b54837c0d870b0e77e076",
            userId:    userId,
            edgeType:  .following,
            maxPages:  maxPages,
            knownIDs:  knownIDs,
            onProgress: onProgress
        )
    }

    // MARK: - Pagination Engine

    private enum EdgeType { case followers, following }

    private func fetchAll(
        queryHash:  String,
        userId:     String,
        edgeType:   EdgeType,
        maxPages:   Int?,
        knownIDs:   Set<String>,
        onProgress: @MainActor @escaping (Int, Int) -> Void
    ) async throws -> FetchResult {
        var results:               [EdgeNode] = []
        var cursor:                String?    = nil
        var pagesFetched                      = 0
        var consecutiveKnownPages             = 0
        var apiTotalCount                     = 0

        repeat {
            try await rateLimiter.wait()
            let connection = try await fetchPage(
                queryHash: queryHash, userId: userId, cursor: cursor, edgeType: edgeType
            )
            apiTotalCount = connection.count
            let pageNodes = connection.edges.map(\.node)
            results.append(contentsOf: pageNodes)
            pagesFetched += 1
            onProgress(results.count, connection.count)

            // Early-stop: once we've fetched at least 2 pages and have a reference set,
            // count consecutive pages where every node is already in knownIDs.
            // Two such pages in a row means the feed has stabilised — stop.
            if pagesFetched >= 2, !knownIDs.isEmpty {
                if pageNodes.allSatisfy({ knownIDs.contains($0.username) }) {
                    consecutiveKnownPages += 1
                    if consecutiveKnownPages >= 2 {
                        return FetchResult(nodes: results, fetchedAll: false, apiTotalCount: apiTotalCount)
                    }
                } else {
                    consecutiveKnownPages = 0
                }
            }

            // Hard page cap (used by partial sync).
            if let maxPages, pagesFetched >= maxPages {
                let hasMore = connection.pageInfo.hasNextPage
                return FetchResult(nodes: results, fetchedAll: !hasMore, apiTotalCount: apiTotalCount)
            }

            cursor = connection.pageInfo.hasNextPage ? connection.pageInfo.endCursor : nil
        } while cursor != nil

        return FetchResult(nodes: results, fetchedAll: true, apiTotalCount: apiTotalCount)
    }

    private func fetchPage(
        queryHash: String,
        userId: String,
        cursor: String?,
        edgeType: EdgeType
    ) async throws -> EdgeConnection {
        var variables: [String: Any] = ["id": userId, "first": 50]
        if let cursor { variables["after"] = cursor }

        guard
            let variablesData = try? JSONSerialization.data(withJSONObject: variables),
            let variablesStr  = String(data: variablesData, encoding: .utf8),
            let encoded       = variablesStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url           = URL(string: "https://www.instagram.com/graphql/query/?query_hash=\(queryHash)&variables=\(encoded)")
        else { throw InstagramAPIError.invalidResponse }

        var request = URLRequest(url: url)
        try applyHeaders(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        let decoded = try JSONDecoder().decode(FollowGraphQLResponse.self, from: data)
        let wrapper = decoded.data.user

        switch edgeType {
        case .followers:
            guard let c = wrapper.edgeFollowedBy else { throw InstagramAPIError.invalidResponse }
            return c
        case .following:
            guard let c = wrapper.edgeFollow else { throw InstagramAPIError.invalidResponse }
            return c
        }
    }

    // MARK: - Unfollow

    /// Destroys the following relationship with `userId` (also cancels a pending follow request).
    func unfollow(userId: String) async throws {
        guard let url = URL(string: "https://i.instagram.com/api/v1/friendships/destroy/\(userId)/") else {
            throw InstagramAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "user_id=\(userId)".data(using: .utf8)
        try applyHeaders(to: &request)
        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func applyHeaders(to request: inout URLRequest) throws {
        guard let sessionId, let csrfToken else { throw InstagramAPIError.unauthorized }

        var cookieParts = ["sessionid=\(sessionId)", "csrftoken=\(csrfToken)"]
        if let userId { cookieParts.append("ds_user_id=\(userId)") }
        if let igDid  { cookieParts.append("ig_did=\(igDid)") }
        if let mid    { cookieParts.append("mid=\(mid)") }

        request.setValue(
            "Instagram 278.0.0.19.115 iOS (iPhone13,4; iOS 16_0; en_US; en; scale=3.00; 1170x2532)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("936619743392459",           forHTTPHeaderField: "X-IG-App-ID")
        request.setValue(csrfToken,                   forHTTPHeaderField: "X-CSRFToken")
        request.setValue(cookieParts.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        request.setValue("1",                         forHTTPHeaderField: "X-Instagram-AJAX")
        request.setValue("XMLHttpRequest",            forHTTPHeaderField: "X-Requested-With")
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw InstagramAPIError.invalidResponse }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw InstagramAPIError.unauthorized
        case 429:       throw InstagramAPIError.rateLimited(retryAfter: 3600)
        default:        throw InstagramAPIError.invalidResponse
        }
    }
}
