# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

This is an Xcode project (no SPM manifest). Use the `BuildProject` MCP tool to build. No external dependencies.

**Targets:** iOS, iPadOS, macOS, visionOS (deployment target 26.2)

**Tests:** Use `RunAllTests` or `RunSomeTests` MCP tools. Test targets are `ToDo TicklerTests` (unit) and `ToDo TicklerUITests` (UI). Tests use the Swift Testing framework.

## Architecture

The app is a SwiftUI reminder manager that wraps Apple's EventKit (Reminders). It does **not** use its own database — all data lives in the system Reminders store, making it interoperable with the built-in Reminders app.

### Data Flow

`ToDo_TicklerApp` creates `ReminderStore` and `LocationManager` as `@State` and injects both into the view hierarchy via `.environment()`. All views read from these observable objects.

### Model Layer

- **ReminderStore** (`@Observable @MainActor`): Wraps `EKEventStore`. Handles authorization, CRUD, and exposes filtered computed properties (`todayReminders`, `availableReminders`, `upcomingReminders`). Listens for `EKEventStoreChangedNotification` to auto-refresh. Uses `withCheckedContinuation` to bridge callback-based EventKit APIs to async/await.

- **TicklerMetadata**: Custom fields that don't map to native `EKReminder` properties are stored as a JSON block inside the reminder's `notes` field, surrounded by delimiter strings. User-written notes are preserved above the block. The struct handles parsing, composition, and round-tripping. Fields: `doOnDate`, `doAtLocation`, `blockedBy` (external ID of blocking task), `markedToday`.

- **LocationManager** (`@Observable @MainActor`): Uses `CLLocationUpdate.liveUpdates()` async sequence. Provides `isNear(_:threshold:)` for proximity checks (default 200m).

### Key Design Decisions

- **`EKReminder.isFlagged` is not in the public Swift API.** The "Today" flag is stored as `markedToday` in the JSON metadata block instead.
- **`calendarItemExternalIdentifier`** (not `calendarItemIdentifier`) is used for `blockedBy` references because it survives iCloud re-syncs.
- **`DateComponents` on reminders require a Gregorian calendar** — Apple raises an exception otherwise. Always set `.calendar = Calendar(identifier: .gregorian)`.
- **iOS requires `startDateComponents` when `dueDateComponents` is set.** The detail view auto-sets start date to match due date if not explicitly set.
- **Metadata dates use ISO 8601 date-only format** (`yyyy-MM-dd`) in UTC.
- **Empty metadata is not persisted** — if all fields are nil/false, the notes field contains only user notes with no delimiter block.

### View Layer

All list views follow the same pattern: `NavigationStack` → filtered `List` → `ReminderRowView` rows → `NavigationLink` to `ReminderDetailView`. Swipe actions for toggle-today and complete.

- **ContentView**: Authorization gate + `TabView` with four tabs (Today, Available, Upcoming, Lists)
- **ReminderRowView**: Reusable row showing completion toggle, title, date chips (start/do-on/due with color coding), blocked indicator, location/today icons, and calendar name
- **ReminderDetailView**: Form editor for all fields. Validates date ordering (start ≤ doOn ≤ due). Has `isNew` mode for creation.

### Filtering Logic

| View | Includes |
|------|----------|
| Today | Overdue, do-on ≤ today, or `markedToday` |
| Available | Start date ≤ today (or none) AND not blocked by incomplete task |
| Upcoming | Start date > today OR do-on date > today |

All filtered views exclude completed reminders and filter to current user or unassigned (via `EKParticipant.isCurrentUser`).

### Date Color Coding in Rows

- **Red**: overdue (due date before today)
- **Green**: due today
- **Blue**: do-on date is today or past
- **Secondary**: future dates

## Entitlements

The app runs in the macOS App Sandbox. Required entitlements in `ToDo_Tickler.entitlements`:
- `com.apple.security.app-sandbox`
- `com.apple.security.network.client` (for iCloud sync)
- `com.apple.security.personal-information.calendars` (EventKit access)
- `com.apple.security.personal-information.location`

The entitlements file must be referenced in the target's `CODE_SIGN_ENTITLEMENTS` build setting. iCloud/Push Notification capabilities are **not** used (they require a paid developer account).

## Cross-Platform

Uses `#if os(iOS)` / `#elseif os(macOS)` for:
- Settings URL (iOS: `UIApplication.openSettingsURLString`, macOS: system preferences URL)
- Keyboard types on text fields (iOS only)
- Tab view styling (`.sidebarAdaptable` on iOS)
