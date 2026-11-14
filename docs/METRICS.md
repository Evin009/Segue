# Metrics

Measured results only. Each number says how and when it was measured.

## Accuracy (real usage)

Measured 2026-11-13 with `segue-eval`: 157 events, 151 switches, 3 days, 12 apps.

| | Predictor | Baseline | Diff |
| --- | --- | --- | --- |
| Top-1 | 53.6% | 43.0% | +10.6 pts (25% relative) |
| Top-3 | 74.8% | 73.5% | +1.3 pts |
| Coverage | 99.3% | 99.3% | 0 |

**Success target** (predictor top-3 beats baseline by 10+ pts): **not met yet.** With only 12 apps, "most-used" is already a strong top-3 guess. Site tracking (Phase 4) is expected to help most. Small sample: re-run after 2+ weeks.

## Speed (synthetic data)

Measured 2026-11-13, release build, 20,000 random events over 40 apps, on this Mac.

| What | Result |
| --- | --- |
| Save one event + update counts | 0.64 ms |
| One prediction (with feedback) | 0.30 ms |
| Replay 5,000 events in eval | about 1 s |
| Database size | about 100 bytes per event (2 MB per 20K) |

## Reliability

| What | Result |
| --- | --- |
| Automated tests | 95, all passing, run in CI on every push |
| Build warnings | 0 (Swift 6 strict concurrency) |
| Failure cases handled | 5: sleep, lock, user switching, launch while locked, missed unlock |
| Lock test (2026-11-10) | ~51 s behind lock screen, 0 s counted |
| Bugs found in real-device testing | 4, all fixed with tests |

## Not measured yet

- Hotkey to popup visible (goal: under 50 ms)
- Memory while running (goal: under 30 MB), idle CPU (goal: about 0%)
- Accept rate, and whether the bandit raises it
- Top-3 after site tracking

## Resume lines (from the numbers above)

```
Segue — Private next-app prediction | Swift 6, SwiftUI, AppKit, SQLite

• Built an on-device next-app predictor for macOS in Swift using a back-off Markov model, achieving 75% top-3 accuracy.
• Benchmarked the model against a most-used-apps baseline on real usage, improving first-guess accuracy by 25%.
• Kept tracking accurate across sleep, lock and user switching, with 0 seconds miscounted in real-device tests.
```

Update the numbers after re-running `segue-eval`.
