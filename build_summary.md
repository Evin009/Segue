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
