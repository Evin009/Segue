# Build Log

What was built in each phase, key decisions, and likely interview questions.

## Phase 0: Setup

**Built:** `SegueCore` Swift package with GRDB 7.12.0, a GitHub Actions workflow that runs its tests, and an empty menu bar app linked to the package.

**Key decisions:**
- Logic lives in a separate package so tests run without the app or UI.
- App sandbox is off, because reading browser tabs later needs it off.
- The app is a menu bar agent (`LSUIElement`), so it has no Dock icon or window.
- Minimum macOS is 26.0, using Swift 6.

**Interview questions:**
- Why split logic into a package instead of keeping it in the app?
- Why ship outside the App Store without the sandbox, and what does that cost?
- What does CI catch that running tests locally doesn't?

## Phase 1: Logging

**Built:** data types, an event cleaner (drops stays under 2s, merges repeats), a SQLite event store that updates 4 tiers of transition counts on every save, and a monitor in the menu bar app that records real app switches, with pause, sleep, screen lock, and user switching.

**Key decisions:**
- Transition counts update in the same database transaction as the event, so they never drift apart.
- Visits split by a short pause or lock count as one visit, so there are no fake "Notes → Notes" switches.
- While the screen is locked or another Mac user is active, nothing is recorded. Launching while locked waits for unlock.
- Pause sticks even if saving fails. The menu error clears only after a real save.
- Recording rules live in `ActivityRecorder` in the package, so they are tested without macOS notifications.

**Known limits (in issues.md):** no "Locked" label in the menu, screensaver time counts toward the previous app, an app split by 10+ pauses loses one count, and a failed save loses 1–2 held visits.

**Interview questions:**
- Why store counts instead of recomputing them from events each time?
- How do you test code that depends on macOS notifications?
- What happens to time spent on the lock screen, and why does it matter for predictions?
