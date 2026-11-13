# Issues

Known problems to fix later. Check this at the start of each phase.

## Phase 3: Popup

- [x] **Stuck "locked":** fixed silently instead of a menu label (no status shown, by choice). Any app switch while "locked" checks the real lock state and resumes if unlocked.

## Phase 4: Browsers

- [ ] **Ignored-app time:** time in front of the screensaver or login screen counts toward the app before it. Fix: treat ignored apps like a lock.
- [ ] **Screensaver app ID:** may be `com.apple.ScreenSaver.Engine.legacyScreenSaver` on current macOS, not the ID in the ignore list. Fix: check against real data.
- [ ] **App split by 10+ pauses:** loses the app that came before it, so one count is missing. Fix: read back further when counting, along with the rebuild work.

## Phase 6: Privacy

- [ ] **Failed save:** if saving to the database fails, the 1–2 visits waiting to save are lost. Fix: keep them and retry, along with the database safety work.

## Anytime

- [ ] **Leftover setting:** the project-level macOS target still says 26.4. The app's own 26.0 setting overrides it, so it has no effect.
