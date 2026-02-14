//
//  RateLimiter.swift
//  UnfollowChecker
//

import Foundation

actor RateLimiter {
    private var requestCount = 0
    private var windowStart  = Date()
    private let maxPerHour   = 200

    /// Enforces rate limits and inserts a random 2–5 s delay between requests.
    func wait() async throws {
        let now     = Date()
        let elapsed = now.timeIntervalSince(windowStart)

        // Reset the window after one hour
        if elapsed >= 3600 {
            requestCount = 0
            windowStart  = now
        }

        // If the hourly cap is reached, sleep until the window resets
        if requestCount >= maxPerHour {
            let remaining = max(0, 3600 - elapsed)
            try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            requestCount = 0
            windowStart  = Date()
        }

        // Random human-like delay between requests
        let delay = Double.random(in: 2...5)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        requestCount += 1
    }
}
