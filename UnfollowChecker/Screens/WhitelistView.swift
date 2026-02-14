//
//  WhitelistView.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

internal import SwiftUI

// MARK: - Whitelist list

struct WhitelistView: View {
    let notFollowingBack: [String]
    @Environment(WhitelistStore.self) var store

    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                if store.whitelists.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Whitelists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddAlert = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.roast)
                    }
                }
            }
            .alert("New Whitelist", isPresented: $showAddAlert) {
                TextField("Name", text: $newName)
                Button("Add") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { store.addWhitelist(named: trimmed) }
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
            .alert("Rename", isPresented: Binding(
                get: { renamingID != nil },
                set: { if !$0 { renamingID = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let id = renamingID {
                        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { store.rename(id, to: trimmed) }
                    }
                    renamingID = nil
                }
                Button("Cancel", role: .cancel) { renamingID = nil }
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(store.whitelists) { wl in
                // Use NavigationLink(value:) so the active-toggle Button
                // in the same row fires independently without being swallowed
                // by the navigation tap target.
                HStack(spacing: 12) {
                    Button {
                        if wl.id == store.activeID {
                            store.deactivate()
                        } else {
                            store.setActive(wl.id)
                        }
                    } label: {
                        Image(systemName: wl.id == store.activeID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(wl.id == store.activeID ? Color.roast : Color.latte.opacity(0.4))
                    }
                    .buttonStyle(.borderless)

                    NavigationLink(value: wl.id) {
                        rowLabel(for: wl)
                    }
                }
                .listRowBackground(Color.foam)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if wl.id == store.activeID {
                        Button { store.deactivate() } label: {
                            Label("Disable", systemImage: "xmark.circle")
                        }
                        .tint(Color.latte)
                    } else {
                        Button { store.setActive(wl.id) } label: {
                            Label("Enable", systemImage: "checkmark.circle")
                        }
                        .tint(Color.roast)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { store.remove(wl) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        renameText = wl.name
                        renamingID = wl.id
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(Color.roast)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.cream)
        .navigationDestination(for: UUID.self) { id in
            WhitelistDetailView(whitelistID: id, notFollowingBack: notFollowingBack)
        }
    }

    @ViewBuilder
    private func rowLabel(for wl: Whitelist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(wl.name)
                    .foregroundStyle(Color.espresso)
                    .fontWeight(wl.id == store.activeID ? .semibold : .regular)
                Text("\(wl.usernames.count) excluded")
                    .font(.caption)
                    .foregroundStyle(Color.latte)
            }

            Spacer()
            let isEnabled = wl.id == store.activeID
            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption.weight(.medium))
                .foregroundStyle(isEnabled ? Color.roast : Color.latte.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isEnabled ? Color.latte.opacity(0.2) : Color.latte.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 52))
                .foregroundStyle(Color.latte)
            Text("No whitelists yet")
                .font(.headline)
                .foregroundStyle(Color.espresso)
            Text("Tap + to create a whitelist.\nUsers in the active list are excluded from your count.")
                .font(.subheadline)
                .foregroundStyle(Color.latte)
                .multilineTextAlignment(.center)
            Button {
                showAddAlert = true
            } label: {
                Label("New Whitelist", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.latte.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.roast)
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding()
    }
}

// MARK: - Whitelist detail

struct WhitelistDetailView: View {
    let whitelistID: UUID
    let notFollowingBack: [String]
    @Environment(WhitelistStore.self) var store

    @State private var query = ""

    private var whitelist: Whitelist? { store.whitelists.first { $0.id == whitelistID } }
    private var excluded: Set<String> { whitelist?.usernames ?? [] }

    private var filtered: [String] {
        guard !query.isEmpty else { return notFollowingBack }
        return notFollowingBack.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            List {
                // Readonly summary of users already in this whitelist
                if !excluded.isEmpty {
                    Section {
                        ForEach(excluded.sorted(), id: \.self) { username in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.roast.opacity(0.6))
                                Text(username)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.espresso.opacity(0.55))
                            }
                            .listRowBackground(Color.latte.opacity(0.08))
                        }
                    } header: {
                        Text("Whitelisted · \(excluded.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.latte)
                    }
                }

                // Toggleable full list
                Section {
                    ForEach(filtered, id: \.self) { username in
                        let isExcluded = excluded.contains(username)
                        Button {
                            store.toggle(username, in: whitelistID)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(isExcluded ? Color.latte.opacity(0.4) : Color.latte)
                                Text(username)
                                    .foregroundStyle(isExcluded ? Color.espresso.opacity(0.35) : Color.espresso)
                                Spacer()
                                Image(systemName: isExcluded ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isExcluded ? Color.roast : Color.latte.opacity(0.4))
                            }
                        }
                        .buttonStyle(.borderless)
                        .listRowBackground(Color.foam)
                    }
                } header: {
                    if !excluded.isEmpty {
                        Text("All users · \(notFollowingBack.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.latte)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.cream)
        }
        .navigationTitle(whitelist?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if whitelistID != store.activeID {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Set active") { store.setActive(whitelistID) }
                        .foregroundStyle(Color.roast)
                }
            }
        }
        .searchable(text: $query, prompt: "Search users")
    }
}

#Preview {
    let store = WhitelistStore()
    store.addWhitelist(named: "Close Friends")
    store.addWhitelist(named: "Brands")
    return WhitelistView(
        notFollowingBack: ["filatov.design", "martina_lo_sasso3", "chiara_croce_"]
    )
    .environment(store)
}
