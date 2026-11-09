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
