//
//  WhitelistStore.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

import Foundation
import Observation

struct Whitelist: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var usernames: Set<String> = []
}

@Observable
final class WhitelistStore {
    var whitelists: [Whitelist] = []
    var activeID: UUID?
    var doneSet: Set<String> = []
    var lastUpdated: Date?

    var activeUsernames: Set<String> {
        whitelists.first { $0.id == activeID }?.usernames ?? []
    }

    init() { load() }

    // MARK: - Whitelist mutations

    func addWhitelist(named name: String) {
        let wl = Whitelist(name: name)
        whitelists.append(wl)
        if activeID == nil { activeID = wl.id }
        save()
    }

    func remove(_ whitelist: Whitelist) {
        whitelists.removeAll { $0.id == whitelist.id }
        if activeID == whitelist.id { activeID = whitelists.first?.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { whitelists[$0].id })
        whitelists = whitelists.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        if let current = activeID, removedIDs.contains(current) {
            activeID = whitelists.first?.id
        }
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let idx = whitelists.firstIndex(where: { $0.id == id }) else { return }
        whitelists[idx].name = name
        save()
    }

    func setActive(_ id: UUID) {
        activeID = id
        save()
    }

    func deactivate() {
        activeID = nil
        save()
    }

    func toggle(_ username: String, in id: UUID) {
        guard let idx = whitelists.firstIndex(where: { $0.id == id }) else { return }
        if whitelists[idx].usernames.contains(username) {
            whitelists[idx].usernames.remove(username)
        } else {
            whitelists[idx].usernames.insert(username)
        }
        save()
    }

    /// Toggles the username in the active whitelist, auto-creating one if none exists.
    func toggleActive(_ username: String) {
        if activeID == nil { addWhitelist(named: "My Whitelist") }
        guard let id = activeID else { return }
        toggle(username, in: id)
    }

    /// Adds username to active whitelist without toggling. Auto-creates list if needed.
    func addToActive(_ username: String) {
        if activeID == nil { addWhitelist(named: "My Whitelist") }
        guard let id = activeID,
              let idx = whitelists.firstIndex(where: { $0.id == id }) else { return }
        whitelists[idx].usernames.insert(username)
        save()
    }

    func isWhitelisted(_ username: String) -> Bool {
        activeUsernames.contains(username)
    }

    // MARK: - Done mutations

    func toggleDone(_ username: String) {
        if doneSet.contains(username) { doneSet.remove(username) } else { doneSet.insert(username) }
        save()
    }

    func resetDone() {
        doneSet = []
        save()
    }

    func markDone(_ username: String) {
        doneSet.insert(username)
        save()
    }

    func isDone(_ username: String) -> Bool {
        doneSet.contains(username)
    }

    // MARK: - Housekeeping

    func recordUpdate() {
        lastUpdated = Date()
        save()
    }

    func prune(keeping valid: Set<String>) {
        for idx in whitelists.indices {
            whitelists[idx].usernames = whitelists[idx].usernames.intersection(valid)
        }
        doneSet = doneSet.intersection(valid)
        save()
    }

    // MARK: - Persistence

    private enum Keys {
        static let whitelists  = "whitelists_v1"
        static let activeID    = "activeWhitelistID_v1"
        static let doneSet     = "doneSet_v1"
        static let lastUpdated = "lastUpdated_v1"
    }

    private func save() {
        if let data = try? JSONEncoder().encode(whitelists) {
            UserDefaults.standard.set(data, forKey: Keys.whitelists)
        }
        UserDefaults.standard.set(activeID?.uuidString, forKey: Keys.activeID)
        if let data = try? JSONEncoder().encode(Array(doneSet)) {
            UserDefaults.standard.set(data, forKey: Keys.doneSet)
        }
        UserDefaults.standard.set(lastUpdated, forKey: Keys.lastUpdated)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Keys.whitelists),
           let decoded = try? JSONDecoder().decode([Whitelist].self, from: data) {
            whitelists = decoded
        }
        if let str = UserDefaults.standard.string(forKey: Keys.activeID),
           let id = UUID(uuidString: str) {
            activeID = id
        }
        if let current = activeID, !whitelists.contains(where: { $0.id == current }) {
            activeID = whitelists.first?.id
        }
        if let data = UserDefaults.standard.data(forKey: Keys.doneSet),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            doneSet = Set(decoded)
        }
        lastUpdated = UserDefaults.standard.object(forKey: Keys.lastUpdated) as? Date
    }
}
