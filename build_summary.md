# Build Summary

What each task did, in plain words, with an example.

## Phase 0: Setup

### Task 1: Code package + CI

**What:** made a home for Segue's logic (`SegueCore`) and set up GitHub to run its tests on every push.

**Example:**
```
You push code → GitHub runs tests → green ✔ or red ✘
```

### Task 2: Menu bar app

**What:** made an empty Mac app that lives in the menu bar. No window, no Dock icon, just a Quit button.

**Example:**
```
Top of screen:  🛜 🔋 ↰ 9:41    ← ↰ is Segue
Click ↰ → "Quit Segue"
```

## Phase 1: Logging

### Task 1: Data types

**What:** defined the basic shapes Segue uses: a time of day and an app switch.

**Example:**
```
9:30 AM  → morning
3:00 PM  → afternoon
Saturday → weekend
```

### Task 2: Event cleaner

**What:** tidies raw app switches so Segue only learns real habits.

**Example:**
```
Mac reports:                     Cleaner keeps:
9:00:00  Slack                   Slack    5 min
9:05:00  Mail     (1 second)     VS Code  15+ min
9:05:01  VS Code
9:20:00  VS Code  (repeat)
```
Mail is dropped, since 1 second isn't a real visit. The repeated VS Code becomes one entry.

### Task 3: Database

**What:** saves each clean event and counts "what came next", so Segue can learn patterns.

**Example:**
```
You use:  Slack → VS Code → Chrome   (morning)

Counts added for Chrome:
  after Slack, VS Code, in the morning  +1
  after VS Code, in the morning         +1
  after VS Code, any time               +1
  overall                               +1
```
A gap over 30 minutes (sleep, overnight) breaks the chain, so Monday night's last app doesn't lead to Tuesday morning's first.

### Task 4: Activity monitor

**What:** connects Segue to your real Mac. Every app switch now goes through the cleaner into the database. Sleep, screen lock and quit save the current app. The menu has a Pause button.

**Example:**
```
You: Chrome → Finder → Notes, then lock screen
Saved: Chrome 4s, Finder 8s, Notes 15s
```
Same app before and after a short pause or lock counts as one visit, so Segue never learns "after Notes comes Notes".
While the screen is locked or another Mac user is active, Segue records nothing until you unlock. Pause always sticks, even if saving fails.
If Segue starts while the screen is already locked, it waits for unlock. The menu's error message clears only after a real save.

## Phase 2: Prediction

### Task 1: Baseline

**What:** the simple guess the predictor must beat. Always suggests your 3 most-used apps, ignoring what you just did and the time of day.

**Example:**
```
History: Chrome ×5, Notes ×3, Mail ×2, Xcode ×1
You're in Chrome → suggests Notes 0.27, Mail 0.18, Xcode 0.09
```
Score = share of all visits. The app you're in is never suggested.

### Task 2: Predictor

**What:** guesses your next app from your last two apps and the time of day. It checks the most specific pattern first and falls back to broader ones when there isn't enough data (under 5 visits).

**Example:**
```
You usually go: Slack → Chrome → Xcode (mornings)
Now: Slack → Chrome, morning → suggests Xcode, score 1.0
Same but only seen 3 times → falls back to "after Chrome, mornings" → lower score
```
Never suggests the app you're in. Suggests nothing if the best guess is under 20% likely.

### Task 3: Scoring

**What:** replays your saved history in order and checks each guess. Before every switch, the guesser sees only what happened earlier, as if live. Reports top-1 (first guess right), top-3 (right answer in the 3), and coverage (how often it suggested anything).

**Example:**
```
History: X → A → B → C, ten times
Predictor: after X → A, guesses B  ✔ (learned the routine)
Baseline:  always guesses most-used app  ✘ often
```
Staying quiet counts as a miss, so the predictor can't look good by only guessing when easy.

### Task 4: Eval tool

**What:** one command that prints predictor vs baseline on your real data. It reads a copy of the database, so it never changes your data, even while Segue is running.

**Example:**
```
swift run --package-path Packages/SegueCore segue-eval

500 events, 200 switches to guess
            Predictor   Baseline     Diff
Top-1           45.0%      20.0%    +25.0
Top-3           75.0%      55.0%    +20.0
Coverage        90.0%     100.0%    -10.0
```
(Made-up numbers.) Under 100 switches, it warns that the numbers are mostly luck.

## Phase 3: Popup

### Task 1: Quiet background tracking

**What:** no status shown. Segue just tracks in the background. The menu has **Stop Monitoring** / **Start Monitoring**. If macOS ever forgets to say the screen unlocked, Segue fixes itself on your next app switch.

**Example:**
```
Unlock signal lost → Segue thinks "still locked"
You switch to Chrome → Segue checks: not locked → records again
```
