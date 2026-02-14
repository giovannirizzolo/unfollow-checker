# UnfollowChecker

An iOS app that shows you who doesn't follow you back on Instagram and lets you bulk-unfollow them — safely, conservatively, and with full control.

## Features

### Home
- **Live counter** — see exactly how many accounts don't follow you back, updated after every sync
- **Unfollow All** — one-tap bulk unfollow with a live gradient progress bar, stop/resume, and a done summary
- **Whitelist guard** — if you have whitelists but none is active, a warning fires before any unfollowing starts
- **Instagram connect** — WebView login, cookie capture, session management all handled in-app

### List
- Filter chips: **All · To Do · Done · Whitelisted · Requested · Failed**
- Search across any filter
- Swipe actions: mark done (left), whitelist / open in Instagram (right)
- Tap a row to open the user's Instagram profile in a built-in browser

### Whitelist
- Create multiple named whitelists
- Activate one at a time to protect those users from bulk actions
- Users protected by the active whitelist are excluded from "Unfollow All" automatically

---

## How it works

### Authentication
Login is handled via a full-screen `WKWebView` pointed at `instagram.com`. After a successful login, cookies (`sessionid`, `csrftoken`, `ds_user_id`, `ig_did`, `mid`) are captured and stored in the iOS Keychain. No credentials are stored in plain text.

### Fetching data
The app uses Instagram's private GraphQL API (the same endpoints the mobile app uses) with a spoofed iOS User-Agent. Followers and following are fetched in pages of 50 via cursor-based pagination.

### Incremental sync
To avoid fetching hundreds or thousands of accounts on every launch, syncs are split into two modes:

| Mode | When | What it does |
|---|---|---|
| **Partial** | Default (within 7 days of last full sync) | Fetches the first 5 pages (~250 accounts), merges into cache. Stops early if 2 consecutive pages are fully known. |
| **Full** | First launch, every 7 days, or on demand | Fetches all pages, replaces cache entirely. |

If the API's reported total count diverges from the last known count by more than 20%, a partial sync is automatically promoted to full.

Cache is stored per-account at `sync_cache_{userId}.json` in the app's Documents directory, written atomically.

### Rate limiting
- **Sync** — 200 requests/hour, 2–5 s random delay between pages
- **Unfollow** — 60 unfollows/hour, 8–15 s random delay between each call

The unfollow queue skips accounts with a pending follow request (private accounts you've requested but they haven't accepted) and marks accounts that return errors as "unavailable".

---

## Project structure

```
UnfollowChecker/
├── Models/
│   ├── InstaUser.swift             Simple username wrapper
│   ├── InstagramAPIModels.swift    Decodable API response types + FetchResult
│   ├── SyncCacheModels.swift       CachedUser, SyncMetadata, SyncMode
│   └── WhitelistStore.swift        @Observable whitelist + done state (UserDefaults)
│
├── Services/
│   ├── KeychainService.swift       Keychain read/write wrapper
│   ├── RateLimiter.swift           Swift actor, configurable per-hour cap + random delay
│   ├── InstagramAPIService.swift   API calls (current user, followers, following, unfollow)
│   ├── FollowerSyncService.swift   @Observable orchestrator, partial/full sync, cache
│   └── UnfollowService.swift       @Observable bulk-unfollow queue with pause/resume
│
├── Screens/
│   ├── HomeView.swift              Root TabView, counter card, unfollow card, sync card
│   ├── ListTab.swift               Filtered list with search, swipe actions, progress banner
│   ├── WhitelistView.swift         Whitelist management
│   ├── AssistModeView.swift        Swipe-card interface for manual processing
│   └── LoginWebView.swift          WKWebView Instagram login + cookie capture
│
└── Services/
    └── InstagramExportParser.swift Parses Instagram JSON data exports (legacy path)
```

---

## Requirements

- iOS 26.2+
- Xcode 26+
- An Instagram account

---

## Privacy

- No data leaves your device except direct calls to Instagram's own API
- Session cookies are stored in the iOS Keychain
- Sync cache lives in the app's sandboxed Documents directory
- No analytics, no third-party SDKs

---

## Disclaimer

This app uses Instagram's private (undocumented) API. Use it responsibly and within Instagram's rate limits. Aggressive use may trigger temporary action blocks on your account.
