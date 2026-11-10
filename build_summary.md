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
