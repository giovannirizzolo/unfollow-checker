# UX Plan — UnfollowChecker

## Service Inventory

| Service | Type | Key State | Notes |
|---|---|---|---|
| `FollowerSyncService` | `@Observable` | `.idle / .validating / .fetchingFollowers / .fetchingFollowing / .done / .failed` | Manages sync, cache, session |
| `UnfollowService` | `@Observable` | `.idle / .running / .paused / .done / .failed` | Bulk unfollow with rate limiting |
| `WhitelistStore` | `@Observable` | `whitelists`, `activeID`, `done` | UserDefaults persistence |
| `InstagramAPIService` | `final class` | `hasValidSession` | Networking, no state |
| `RateLimiter` | `actor` | Configurable per-hour cap | Shared via composition |

---

## Home Tab — UX Anchor

### Layout (top → bottom)

1. **Count card** — large skull emoji + number + "don't follow back" label + last-synced timestamp
2. **Status pills row** — sync status pill, cleanup status pill (when active)
3. **"Clean up" primary button** — leads to `CleanupConfirmSheet`
4. **"View list" secondary button** — switches tab to List
5. **`apiCard`** — Instagram connect / sync controls (secondary, at bottom)

### State gates

| Condition | "Clean up" button |
|---|---|
| No sync yet | Hidden (disabled) |
| `cleanupUsers.isEmpty` | Hidden |
| Cleanup running | Replaced by `CleanupProgressView` launcher |
| Cleanup paused/done | Resume / Dismiss shown |

### Auto-sync on appear

- Throttle: 15-minute window (UI-only, `@State private var lastAutoSync: Date?`)
- Triggers only when session is valid and sync is idle
- Does NOT run a full sync (uses `startSync()` which picks the right mode)

### Safety onboarding

- Triggers after first successful sync (`syncService.state == .done && !hasSeenSafetyOnboarding`)
- Stores seen flag in `@AppStorage("hasSeenSafetyOnboarding")`
- Re-openable from `?` toolbar button

---

## List Tab — Simplified

### Filter chips (3 total)

| Chip | Shows |
|---|---|
| **All** | All `notFollowingBack` |
| **Not Whitelisted** | `notFollowingBack.filter { !store.isWhitelisted($0) }` |
| **Whitelisted** | `notFollowingBack.filter { store.isWhitelisted($0) }` |

### Row

- Username (primary)
- Status badge: Whitelisted · Done · Pending
- Swipe left: mark done
- Swipe right: whitelist toggle, open in Instagram
- Tap: open `UserDetailSheet`

### Removed from v1 List

- "To Do", "Done", "Requested", "Failed" filter chips
- "Unfollow All" toolbar button (moved to Home)

---

## Global Progress Banner

`ProgressBanner` sits as `.safeAreaInset(edge: .bottom)` on the root `TabView`.

- Visible only when `unfollowService.state == .running`
- Shows slim progress bar + "Cleaning X%"
- Tapping opens `CleanupProgressView` as a sheet

---

## New Components

| File | Purpose |
|---|---|
| `UI/StatusPill.swift` | Capsule pill: syncing / synced / error / cleaning / offline |
| `UI/ProgressBanner.swift` | Slim global progress banner across tabs |
| `Screens/Onboarding/SafetyOnboardingCard.swift` | Single onboarding page |
| `Screens/Onboarding/SafetyOnboardingView.swift` | 3-page TabView onboarding flow |
| `Screens/CleanupConfirmSheet.swift` | Pre-cleanup confirmation sheet |
| `Screens/CleanupProgressView.swift` | Full-screen cleanup progress |
