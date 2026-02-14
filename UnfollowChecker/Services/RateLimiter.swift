//
//  RateLimiter.swift
//  UnfollowChecker
//

import Foundation

actor RateLimiter {
    private var requestCount = 0
    private var windowStart  = Date()
    private let maxPerHour:  Int
    private let delayRange:  ClosedRange<Double>

    /// - Parameters:
    ///   - maxPerHour: Maximum requests allowed per rolling hour window (default 200 for fetch).
    ///   - delayRange: Random pause in seconds injected before each request (default 2–5 s).
    init(maxPerHour: Int = 200, delayRange: ClosedRange<Double> = 2...5) {
        self.maxPerHour = maxPerHour
        self.delayRange = delayRange
    }

    func wait() async throws {
        let now     = Date()
        let elapsed = now.timeIntervalSince(windowStart)

        if elapsed >= 3600 {
            requestCount = 0
            windowStart  = now
        }

        if requestCount >= maxPerHour {
            let remaining = max(0, 3600 - elapsed)
            try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            requestCount = 0
            windowStart  = Date()
        }

        let delay = Double.random(in: delayRange)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        requestCount += 1
    }
}
