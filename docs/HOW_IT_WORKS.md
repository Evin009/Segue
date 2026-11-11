# How Segue Works

A simple guide to what's under the hood. Read top to bottom once, then use it to review before interviews.

---

## 1. The big picture

```
 You switch apps
      │
      ▼
 Monitor ──► Cleaner ──► Database ──► Predictor ──► top 3 suggestions
                         (diary +                        │
                          tallies)                       ▼
                                              Eval: "was it right?"
```

| Part | Job | File |
| --- | --- | --- |
| Monitor | Notices app switches, sleep, lock, quit | `SegueApp/.../ActivityMonitor.swift` |
| Cleaner | Drops accidents (under 2 s) and repeats | `Cleaning/EventCleaner.swift` |
| Database | Saves each visit and counts "what came next" | `Storage/EventStore.swift` |
| Predictor | Guesses the next app | `Prediction/Predictor.swift` |
| Baseline | Simple guesser to beat: "most-used apps" | `Prediction/BaselinePredictor.swift` |
| Eval | Grades both guessers on your real history | `Prediction/Evaluator.swift`, `segue-eval` |

---

## 2. One example, start to finish

For 8 mornings you did:

- 6 times: **Slack → Chrome → Xcode**
- 2 times: **Slack → Chrome → Mail**

### Step 1: Cleaner removes noise

```
Slack 5 min → Finder 1 sec → Chrome 7 min
                 ↑ under 2 s = accident, dropped
```

### Step 2: Database saves a diary and tallies

**Diary** (`events` table): one row per visit.

```
9:00  Slack   300s  morning
9:05  Chrome  420s  morning
9:12  Xcode   900s  morning
```

**Tallies** (`transitions` table): each saved visit adds +1 at 4 levels.

```
Level 1  after Slack → Chrome, morning   Xcode 6, Mail 2
Level 2  after Chrome, morning           Xcode 6, Mail 2
Level 3  after Chrome, any time          Xcode 6, Mail 2
Level 4  overall                         Slack 8, Chrome 8, Xcode 6, Mail 2
```

A gap over 30 minutes (lunch, sleep) breaks the chain: yesterday's last app doesn't lead to today's first.

### Step 3: Predictor guesses

**Now:** morning, came from Slack, in Chrome.

1. Read level 1: Xcode 6, Mail 2. Total 8, which is 5 or more, so it's trusted.
2. Score = level multiplier × probability:
   - Xcode: 1 × 6/8 = **0.75**
   - Mail: 1 × 2/8 = **0.25**
   - Slack (from level 4): 0.064 × 8/24 = **0.02**
3. Remove Chrome (you're in it).
4. Best guess is 75% likely, at least 20%, so show it.
5. **Result: Xcode, Mail, Slack.**

**If you came from Finder instead:** level 1 has no data, so it steps back to level 2 (multiplier 0.4). Xcode = 0.4 × 0.75 = 0.30. Same order, lower confidence.

### Step 4: Eval grades it

Replays history like a movie. Before each switch, the predictor knows **only the past**:

```
Slack            nothing before it → no question
Chrome           knows [Slack]         → guess → right?
Xcode            knows [Slack, Chrome] → guess → right?
```

Guess first, save after. It never sees the answer early.

---

## 3. The model: what it is

### Markov chain

Predicts the next thing **from only the last few things**.
"After Chrome, Xcode came 6 of 8 times → 75%." Phone keyboards work the same way.

### Back-off

More context is more precise, but each exact situation is seen less often. Back-off means: **use the most specific context you can trust; step back to broader context when data is thin.**

Café example: guessing a friend's order.

1. What does she get here on Monday mornings? Seen 10 times → latte.
2. Seen only once? Step back: what does she get here in general?
3. Still unsure? What does she drink anywhere?
4. Last resort: what do most people order?

| Level | Context | Multiplier | Used when |
| --- | --- | --- | --- |
| 1 | Last 2 apps + time of day | 1 | 5+ visits |
| 2 | Last app + time of day | 0.4 | 5+ visits |
| 3 | Last app, any time | 0.16 | 5+ visits |
| 4 | Overall usage | 0.064 | Always |

Each step back is worth 0.4× the one before, so specific beats general.

### Exact name

> **N-gram model with back-off**, also called a **variable-order Markov chain**, with time of day as extra context.

The 0.4 multiplier comes from **"Stupid Backoff"** (Brants et al., Google, 2007). "Stupid" because scores aren't true probabilities, just good for ranking. Ranking is all Segue needs.

**Our twist:** standard back-off steps back only when a count is zero. Ours steps back when it's under 5, because one person's data is small and noisy.

### Rules

| Rule | Why |
| --- | --- |
| Skip levels with under 5 visits | With 2 visits, one fluke is 50%. Too noisy. |
| Never suggest the current app | You're already in it. |
| Skip apps dismissed in the last 4 hours | Don't repeat what you said no to. |
| Stay quiet if best guess is under 20% likely | A bad suggestion is worse than none. |
| The 20% check uses probability, not score | Scores are shrunk on purpose for broad levels. 80% likely is still confident. |
| Top 3, ties sorted by name | Same input always gives the same output. |

---

## 4. Eval: grading the model

**Eval = evaluation = grading an exam.**

- **Exam:** your real history, replayed step by step
- **Question:** "You're in Chrome after Slack. What's next?"
- **Answer key:** what you really opened
- **Rule:** no peeking. Only past data at each question.

| Number | Meaning |
| --- | --- |
| Top-1 | First guess was right |
| Top-3 | Right answer was in the 3 guesses |
| Coverage | How often it guessed at all |

**Staying quiet counts as wrong**, so the model can't look good by only guessing when it's easy.

**Is eval part of the product?** It's a tool for the builder, not a feature for users. It gives real numbers for the resume and decides whether later ideas (AI, bandit, neural network) stay.

**Run it:**

```
swift run --package-path Packages/SegueCore segue-eval
```

Needs 100+ switches to mean anything. Reads a copy of the database, so real data is never changed.

**Success target:** set before seeing results: predictor's top-3 beats baseline's by 10+ points.

---

## 5. Why counting, not a neural network?

| | Counting (ours) | Neural network |
| --- | --- | --- |
| Data needed | Works in a day or two | Thousands of switches |
| Speed | About a millisecond | Slower |
| Explain a guess | "Xcode came after Chrome 6 of 8 times" | Hard |
| Invents apps | Never | Can (language models) |
| Privacy | Simple, on-device | Needs on-device training |

Neural networks and RL need **more** data, not less, so they don't fix the slow start.

**Plan for AI anyway (each kept only if eval shows it helps):**

- **Phase 3:** a bandit (simple RL) learns from accept and dismiss
- **Phase 5:** AI guesses on day 1, from apps you have, fading out as data grows
- **Phase 5:** AI writes one-line explanations from the real counts
- **Phase 8:** a small neural network vs counting; keep the winner

**Biggest accuracy gain is likely better information, not a fancier model:** knowing you're on github.com vs youtube.com (Phase 4) should help more than switching models.

---

## 6. Interview script (about 90 seconds)

> "Segue is a Mac menu bar app that predicts which app you'll open next and suggests the top three.
>
> It listens for app switches from macOS, and a cleaning step throws away accidental ones, anything under two seconds. Each real switch goes into a local SQLite database, and in the same transaction I update counts of what followed what.
>
> I keep those counts at four levels, from most to least specific: last two apps plus time of day, last app plus time of day, last app at any time, and overall usage. To predict, I use a **back-off model**. I start with the most specific level, and if it has fewer than five observations I treat it as noise and step back to a broader one. Broader levels are down-weighted, so a specific pattern always outranks a general one. If even the best guess is under 20% likely, it stays quiet, because a bad suggestion is worse than none.
>
> I chose counting over a neural network on purpose. One person generates a few hundred switches a week. That's too little for a neural net, and counting is fast, private, and explainable: I can say *why* it suggested something.
>
> To test it, I built a replay evaluator. It walks through history in order, and before each switch the model sees only earlier data, so there's no leakage. Staying quiet counts as a miss. I compare against a 'most-used apps' baseline, and I set the success target before looking at results.
>
> **[Result: on X weeks of my data, top-3 accuracy was Y% vs Z% baseline.]**"

**Fill in the brackets only with real numbers.** Until then say: "I'm collecting data now; the evaluator is ready."

**One-liner:**

> "It's a second-order Markov model with time-of-day context, using a Stupid Backoff–style scheme: I use the longest context with at least five observations and down-weight each step back by 0.4."

---

## 7. Quick quiz

1. **Why skip levels with under 5 visits?** Too few to trust; one fluke swings it.
2. **Why does the 20% check use probability, not score?** Scores are shrunk for broad levels on purpose; probability says how sure we really are.
3. **Why guess before saving in eval?** So the model never sees the answer. Otherwise it's data leakage.
4. **Why does staying quiet count as a miss?** Otherwise the model looks perfect by only guessing easy ones.
5. **Why keep tallies instead of recounting the diary?** A tally is one quick lookup, however long the history.
6. **Why not a neural network?** Too little data from one person, slower, hard to explain. Phase 8 tests it anyway.
7. **What's the 0.4?** From Stupid Backoff: each step to broader context is worth 0.4× the one before.
