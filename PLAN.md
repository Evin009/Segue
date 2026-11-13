# Segue

Mac menu bar app that learns your app and website habits and suggests what to open next. Everything stays on your Mac.

**Why:** portfolio project for Apple internship teams. Every part must be defensible in an interview.

**Big idea:** a simple statistical model picks suggestions. AI explains them and helps on day 1 before there is data. Every model choice is decided by measured accuracy, not guesses.

## Features

- **Next-step suggestions:** top 3 apps or sites, based on your last two and the time of day
- **Quick popup:** Spotlight-style, opened by hotkey; 1/2/3 or arrows + Return accept, Esc dismisses
- **Learns from you:** accepted suggestions rank higher, dismissed ones lower
- **Website tracking:** opt-in per browser; stores site name only, never full URLs or page titles
- **AI explanations:** one-line reason for each suggestion, with a plain fallback
- **Commands:** "open my usual morning apps"
- **Privacy controls:** encrypted data, site blocklist, pause, delete, 45-day auto-delete

## How it works

Activity → Cleaner → Database → Predictor → Popup → your feedback → Database

**Stack:** Swift 6, SwiftUI + AppKit, SQLite (GRDB + SQLCipher), Apple Foundation Models, GitHub Actions. macOS 26+.

**Code:** `Packages/SegueCore` = testable logic. `SegueApp/` = UI and Mac code. `docs/HOW_IT_WORKS.md` = simple guide + interview script. `docs/LOG.md` = phase notes. `docs/METRICS.md` = measured results.

**Success target (set before real data):** predictor top-3 beats baseline top-3 by 10+ points.

**Predictor:** check most specific first; tiers 1–3 need total weight of at least 5.

| Tier | Looks at | Score |
| ---- | --------------------------- | ------------------- |
| 1 | last 2 states + time of day | probability |
| 2 | last state + time of day | 0.4 × probability |
| 3 | last state | 0.16 × probability |
| 4 | overall frequency | 0.064 × probability |

Option keeps score from first tier it appears in. Remove current state and anything dismissed here in the last 4 hours. Keep top 3, ties sorted by name. Suggest nothing if top option's plain probability is under 0.2.

**Starting values:** 2 s minimum stay, 30 min session gap, 0.97 daily fade, ±1 feedback, top 30 sites. Morning 5–12, afternoon 12–17, evening 17–22, night 22–5.

## Rules

- Claude explains each step and command first
- Claude wrote the predictor at your request; you must be able to explain every line
- Only measured numbers go in README or resume
- Small tasks, tests pass before commit, no push without your OK
- Finish Phases 0–4 (MVP) first

## Execution plan

### Phase 0: Setup

- [x] Code package + CI: project skeleton tests itself on every push
- [x] Menu bar app: empty app with icon and Quit (you click through Xcode)

### Phase 1: Logging

- [x] Data types: define app switch and time of day
- [x] Cleaner: drop accidental switches and duplicates
- [x] Database: save switches, count what follows what; overnight gaps don't count
- [x] Monitor: record real switches; run daily from here on

### Phase 2: Prediction

- [x] Baseline: "most used apps" guess for predictor to beat
- [x] Predictor: guess next app from last two (Claude wrote it at your request; you explain it)
- [x] Scoring: replay past activity using only earlier data; measure top-1, top-3, and how often it suggests
- [x] Eval tool: print predictor vs baseline on real data

### Phase 3: Popup

- [x] Feedback: learn from accept/dismiss with a bandit (simple RL) instead of plain ±1
- [ ] Popup + hotkey: show top 3 without stealing focus

### Phase 4: Browsers (MVP done)

- [ ] Site cleanup: keep site name only; blocking `bank.com` also blocks subdomains
- [ ] Upkeep: fade old habits, delete old data, rebuild counts
- [ ] Browser reading: read site safely; skip incognito; Safari off by default if private windows are undetectable
- [ ] Settings: choose browsers, edit blocklist
- [ ] Compare: after a week of data, test if tracking sites helps

### Phase 5: AI

- [ ] Fact check: reject explanations with made-up numbers
- [ ] Explanations: one-line reason, plain fallback when AI is unavailable
- [ ] Day-1 AI: AI guesses from known apps while data is thin, fading out as counts grow; keep only if scoring shows it helps
- [ ] Commands: AI opens only apps and sites predictor already knows

### Phase 6: Privacy

- [ ] Encryption: lock database, keep key in Keychain; never overwrite a database that won't open
- [ ] Delete controls: delete data, set retention, write privacy page

### Phase 7: On-device vs cloud AI

- [ ] Check access (**you**): can a non-App Store app use Apple's cloud model?
- [ ] Compare: test speed and quality on fake data only; real activity stays on Mac

### Phase 8: Stretch

- [ ] Neural network vs counting: train a small on-device model on weeks of data; keep whichever scores better

### Phase 9: Ship

- [ ] Signed build (**you**): pick final name, sign, notarize
- [ ] Launch: README, 60-second demo, resume bullets from real numbers

## Open questions


- Final name?
- Should popup auto-show? Decide from accept-rate data.
