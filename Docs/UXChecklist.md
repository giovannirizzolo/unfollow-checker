# UX End-to-End Checklist

## Scenario 1 — First Launch (No Session)

| Check | Expected |
|---|---|
| Counter card shows placeholder | ✅ "No data yet" with skull emoji |
| "Clean up" button hidden | ✅ Gated on `syncService.lastSyncDate != nil` |
| Status pills empty | ✅ No pills shown before first sync |
| apiCard shows "Connect Instagram" | ✅ `syncService.hasValidSession == false` |
| Login flow opens WebView | ✅ `showLogin = true` |

---

## Scenario 2 — First Sync Completes

| Check | Expected |
|---|---|
| Counter updates immediately | ✅ `applyAPISync()` called in `.onChange(of: syncService.state)` |
| Safety onboarding fires | ✅ `!hasSeenSafetyOnboarding && syncService.state == .done` |
| Onboarding can be dismissed via swipe | ✅ `interactiveDismissDisabled(false)` |
| Onboarding sets `hasSeenSafetyOnboarding = true` | ✅ On last page Continue / Skip |
| `?` toolbar button reopens onboarding | ✅ `showOnboarding = true` |
| Status pill shows "Updated X" | ✅ `.synced(date)` StatusPill |
| apiCard shows next sync mode | ✅ "Next: partial / full sync" label |

---

## Scenario 3 — Start Cleanup

| Check | Expected |
|---|---|
| "Clean up" tap → confirm sheet | ✅ `showCleanupConfirm = true` |
| Confirm sheet shows correct count | ✅ Reads `cleanupUsers.count` |
| Whitelist info shown if list active | ✅ Conditional on `hasActiveList` |
| Whitelist warning fires if lists exist but none active | ✅ Alert before showing confirm |
| Confirm → `startUnfollowNow()` | ✅ Sheet dismisses then starts queue |
| Progress banner appears on all tabs | ✅ `.safeAreaInset` on TabView |
| Banner tap → full progress sheet | ✅ `showCleanupProgress = true` |
| Cleanup status pill shown on Home | ✅ `.cleaning(cur, tot)` StatusPill |

---

## Scenario 4 — Cleanup Ends

| Check | Expected |
|---|---|
| Done summary shown | ✅ `.done(succeeded:failed:)` case in unfollowCard |
| Processed users marked done in store | ✅ `UnfollowService` calls `store.markDone(_:)` |
| Counter decrements | ✅ `cleanupUsers` is always derived, never persisted |
| Progress banner disappears | ✅ Banner only shown in `.running` state |
| CleanupProgressView shows "All done!" | ✅ `.done` case in `CleanupProgressView` |

---

## Scenario 5 — Error States

| Check | Expected |
|---|---|
| Sync error shows pill | ✅ `.syncError` StatusPill with retry |
| Sync error alert shown | ✅ `syncError` state drives alert |
| Cleanup auth error → paused + message | ✅ `.failed("Session expired")` case |
| Cleanup rate-limit hit → paused | ✅ `.paused` state, user can resume |
| No crash on nil data | ✅ All UI gated on optional unwrapping |

---

## Scenario 6 — Safety Onboarding

| Check | Expected |
|---|---|
| Shown only after first successful sync | ✅ Triggered in `.onChange` for `.done` state |
| Only shown once | ✅ `@AppStorage("hasSeenSafetyOnboarding")` |
| Skip works immediately | ✅ Sets flag + dismisses |
| Swipe dismiss works | ✅ `interactiveDismissDisabled(false)` |
| Reopenable from `?` toolbar | ✅ `Button("?") { showOnboarding = true }` |
| Success haptic on last page | ✅ `UINotificationFeedbackGenerator().notificationOccurred(.success)` |
