//
//  InstagramExportParser.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

import Foundation

enum InstagramExportParser {
    /// Parses usernames from either Instagram export format:
    /// - followers_1.json: top-level array, username at `string_list_data[0].value`
    /// - following.json:   top-level object `{ relationships_following: [...] }`, username at `title`
    static func parseUsernames(from jsonData: Data) throws -> [String] {
        let raw = try JSONSerialization.jsonObject(with: jsonData, options: [])

        // followers_1.json format
        if let arr = raw as? [[String: Any]] {
            return arr.compactMap { item in
                guard
                    let sld = item["string_list_data"] as? [[String: Any]],
                    let first = sld.first,
                    let value = first["value"] as? String
                else { return nil }
                return value
            }
        }

        // following.json format
        if let obj = raw as? [String: Any],
           let arr = obj["relationships_following"] as? [[String: Any]] {
            return arr.compactMap { ($0["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        }

        return []
    }

    static func computeNotFollowingBack(followers: [String], following: [String]) -> [String] {
        let followerSet = Set(followers)
        return following.filter { !followerSet.contains($0) }.sorted()
    }
}
