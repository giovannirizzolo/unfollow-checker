//
//  ListTab.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

internal import SwiftUI
import WebKit

// MARK: - List tab

struct ListTab: View {
    let notFollowingBack: [String]
    @Environment(WhitelistStore.self) var store
    @Environment(\.openURL) private var openURL

    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var selectedUser: String?
    @State private var navigateToAssist = false

    enum Filter: String, CaseIterable {
        case all       = "All"
        case todo      = "To Do"
        case done      = "Done"
        case whitelist = "Whitelisted"
    }

    private var cleanupUsers: [String] {
        notFollowingBack.filter { !store.isWhitelisted($0) && !store.isDone($0) }
    }

    private var filtered: [String] {
        let base: [String]
        switch filter {
        case .all:       base = notFollowingBack
        case .todo:      base = notFollowingBack.filter { !store.isWhitelisted($0) && !store.isDone($0) }
        case .done:      base = notFollowingBack.filter { store.isDone($0) }
        case .whitelist: base = notFollowingBack.filter { store.isWhitelisted($0) }
        }
        guard !query.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                VStack(spacing: 0) {
                    filterChips
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.foam)

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        userList
                    }
                }
            }
            .navigationTitle("List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !cleanupUsers.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Assist") { navigateToAssist = true }
                            .foregroundStyle(Color.roast)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search users")
            .navigationDestination(isPresented: $navigateToAssist) {
                AssistModeView(users: cleanupUsers)
            }
            .sheet(item: Binding(
                get: { selectedUser.map { UserID(value: $0) } },
                set: { selectedUser = $0?.value }
            )) { uid in
                UserDetailSheet(username: uid.value)
            }
        }
    }

    // MARK: - Filter chips

    private func chipCount(for f: Filter) -> Int {
        switch f {
        case .all:       return notFollowingBack.count
        case .todo:      return notFollowingBack.filter { !store.isWhitelisted($0) && !store.isDone($0) }.count
        case .done:      return notFollowingBack.filter { store.isDone($0) }.count
        case .whitelist: return notFollowingBack.filter { store.isWhitelisted($0) }.count
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases, id: \.self) { f in
                    Button {
                        filter = f
                    } label: {
                        Text("\(f.rawValue) (\(chipCount(for: f)))")
                            .font(.subheadline.weight(filter == f ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(filter == f ? Color.roast : Color.latte.opacity(0.18))
                            .foregroundStyle(filter == f ? .white : Color.roast)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - User list

    private var userList: some View {
        List {
            ForEach(filtered, id: \.self) { username in
                row(for: username)
                    .listRowBackground(Color.foam)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .listStyle(.plain)
        .background(Color.cream)
    }

    @ViewBuilder
    private func row(for username: String) -> some View {
        let isDone = store.isDone(username)
        let isWhitelisted = store.isWhitelisted(username)

        Button { selectedUser = username } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isDone ? Color.latte.opacity(0.4) : Color.latte)

                VStack(alignment: .leading, spacing: 2) {
                    Text(username)
                        .font(.subheadline)
                        .foregroundStyle(isDone ? Color.espresso.opacity(0.4) : Color.espresso)
                    if isDone {
                        Text("Done")
                            .font(.caption2)
                            .foregroundStyle(Color.latte.opacity(0.7))
                    } else if isWhitelisted {
                        Text("Whitelisted")
                            .font(.caption2)
                            .foregroundStyle(Color.latte.opacity(0.7))
                    }
                }

                Spacer()

                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.roast.opacity(0.5))
                } else if isWhitelisted {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.latte.opacity(0.5))
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderless)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                store.toggleDone(username)
            } label: {
                Label(isDone ? "Undo" : "Done", systemImage: isDone ? "arrow.uturn.left" : "checkmark")
            }
            .tint(isDone ? Color.latte : Color.roast)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                store.toggleActive(username)
            } label: {
                Label(isWhitelisted ? "Un-whitelist" : "Whitelist", systemImage: "star")
            }
            .tint(Color.latte)

            Button {
                openInstagram(username)
            } label: {
                Label("Open", systemImage: "safari")
            }
            .tint(Color.espresso)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(Color.latte)
            Text("Nothing here")
                .font(.headline)
                .foregroundStyle(Color.espresso)
            Text("No users match this filter.")
                .font(.subheadline)
                .foregroundStyle(Color.latte)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func openInstagram(_ username: String) {
        let appURL = URL(string: "instagram://user?username=\(username)")!
        let webURL = URL(string: "https://instagram.com/\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else {
            openURL(webURL)
        }
    }
}

// MARK: - Identifiable wrapper for sheet

private struct UserID: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - User detail sheet

struct UserDetailSheet: View {
    let username: String
    @Environment(WhitelistStore.self) var store
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                ProfileWebView(username: username)
            }
            .navigationTitle(username)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.roast)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openInstagram(username)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.roast)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            let isWhitelisted = store.isWhitelisted(username)
            let isDone = store.isDone(username)

            Button {
                store.toggleActive(username)
            } label: {
                Label(isWhitelisted ? "Remove from whitelist" : "Whitelist",
                      systemImage: isWhitelisted ? "star.slash" : "star")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.latte.opacity(0.2))
                    .foregroundStyle(Color.roast)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.borderless)

            Button {
                store.toggleDone(username)
            } label: {
                Label(isDone ? "Undo" : "Mark done",
                      systemImage: isDone ? "arrow.uturn.left" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isDone ? Color.latte.opacity(0.2) : Color.roast)
                    .foregroundStyle(isDone ? Color.roast : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func openInstagram(_ username: String) {
        let appURL = URL(string: "instagram://user?username=\(username)")!
        let webURL = URL(string: "https://instagram.com/\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else {
            openURL(webURL)
        }
    }
}

// MARK: - Profile web view (used by UserDetailSheet)

struct ProfileWebView: UIViewRepresentable {
    let username: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let urlString = "https://www.instagram.com/\(username)/"
        guard let url = URL(string: urlString) else { return }
        if wv.url?.absoluteString != urlString {
            wv.load(URLRequest(url: url))
        }
    }
}

#Preview {
    let store = WhitelistStore()
    return ListTab(notFollowingBack: ["user_a", "user_b", "user_c"])
        .environment(store)
}
