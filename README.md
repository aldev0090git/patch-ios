# Patch

A goal and habit tracker for iOS, built in SwiftUI.

Reading twenty minutes a day, a hundred push-ups, two litres of water, money put
aside, a day without smoking — Patch treats all of these as the same thing, and
that single idea shapes the whole codebase.

> **Status: in development.** The domain layer is complete and tested. The app
> target, persistence and UI are being built on top of it. See [Roadmap](#roadmap).

---

## The core idea

Most habit trackers model each kind of goal separately, which means every new
goal type touches the schema, the UI and the statistics code. Patch doesn't.
Every goal is *an amount accumulated toward a daily target, in a direction*:

| Goal | Kind | Direction | Logged as |
|---|---|---|---|
| Read 20 minutes | `duration` | `atLeast` | 10 min + 10 min |
| 100 push-ups | `count` | `atLeast` | 20 + 30 + 50 |
| 2 litres of water | `volume` | `atLeast` | 8 × 250 ml |
| Don't smoke | `count` | `atLeast` 1 | one confirmation a day |
| Save 100 UAH | `currency` | `atLeast` | one or more deposits |
| 10 000 steps | `count` | `atLeast` | filled in from HealthKit |

Adding a new kind of goal means adding a `MeasureKind`, not migrating the store
or branching the UI.

Two consequences fall out of this that are worth calling out:

**Patch records what you did, never what you avoided.** "Don't smoke" was first
modelled as `atMost 0`, so a day with no entries already succeeded and the only
available action was admitting a slip — a button that undoes the user's own
goal, sitting on a row already marked complete. It now works like any other
once-a-day goal: you confirm it. The tick means you actually said so, rather
than meaning the clock has not caught you yet.

**Amounts are always stored in a canonical unit** — seconds, millilitres, metres.
Display units are a presentation concern. Totals, comparisons and (later) sync
never have to care how a number was entered.

## Architecture

```
Packages/PatchKit/
  Sources/PatchCore/        Pure Swift. No SwiftUI, no SwiftData, no UIKit.
    Measure.swift           What a goal asks of a day
    Schedule.swift          Which days it asks on
    Goal.swift              The goal itself
    Entry.swift             One logged contribution
    DayProgress.swift       How one goal stands on one day
    ProgressCalculator.swift
    StreakCalculator.swift
    QuickAdd.swift          Suggested one-tap logging amounts
    Statistics.swift        Done/missed over day, week, month, year, custom
    GoalTemplate.swift      Ready-made goals for onboarding
    GoalStore.swift         The persistence contract, plus an in-memory store
  Sources/PatchStore/       The only place that imports SwiftData
  Tests/                    84 tests, ~20ms, no simulator needed

Patch/                      SwiftUI app target
  Patch/Localizable.xcstrings   English, Ukrainian, Russian
```

The domain layer imports nothing but `Foundation`. That is the point: all the
logic worth testing — progress, clamping, streaks, schedules, corrections —
is testable in milliseconds without booting a simulator, and persistence can be
swapped without touching any of it.

**Calendars are injected, never global.** `ProgressCalculator` and
`StreakCalculator` take a `Calendar`, so tests pin UTC and a Monday first-weekday
and behave identically on a laptop in Kyiv and a CI runner elsewhere.

**Entries are append-only in spirit.** Correcting a mistake adds a negative
amount rather than mutating history, which keeps a day's total auditable and
avoids edit conflicts once CloudKit sync is enabled.

### Two product rules encoded in the domain

Both are deliberate, documented and tested:

- **Unscheduled days are skipped, not failed.** A weekday-only gym habit keeps
  its streak across the weekend.
- **Today is forgiving.** If today is scheduled but not yet done, the streak is
  measured from yesterday rather than displayed as zero. Resetting someone's
  streak at 00:01 punishes them for the clock, not their behaviour.
- **"Missed" means genuinely missed.** Statistics exclude days before the goal
  was created, days still in the future, and an unfinished today. Without this,
  every new goal opens on a wall of red for a month it was never set during.

### Logging should take one tap, and fit the goal

A goal's shape decides how it is logged, so the domain exposes a `LoggingStyle`
rather than leaving the view to guess: goals that accumulate get a row of
amounts, goals that happen once a day get a single **Done** button. Either way
**Reset** clears the day.


Suggested amounts scale with the target and snap to round numbers people
actually say, so logging never requires a picker:

| Goal | Suggestions |
|---|---|
| Read 20 minutes | 5 min · 10 min · 20 min |
| 100 push-ups | 25 · 50 · 100 |
| 2 litres of water | 500 ml · 1 L · 2 L |
| 10 000 steps | 2 000 · 5 000 · 10 000 |

Three, plus **Manual** for anything else — four equal slots, so every goal's
controls line up down the screen rather than each row finding its own rhythm.
Manual opens a picker over the goal's own range, defaulted to the amount still
needed, since that is overwhelmingly the value people want.

## Getting started

```bash
git clone git@github.com:aldev0090git/patch-ios.git
cd patch-ios

# Run the app
open Patch/Patch.xcodeproj

# Or just the domain layer — no Xcode project needed
cd Packages/PatchKit && swift test
```

Requires **Xcode 27 or later** to open the project. The app itself targets
**iOS 26.0**, so it runs on the previous OS release as well as the current one.

## Roadmap

- [x] Domain model — measures, schedules, progress, streaks
- [x] Quick-add suggestion engine
- [x] Statistics — done/missed over day, week, month, year, custom ranges
- [x] Onboarding goal templates
- [x] Unit test suite — 52 tests
- [x] CI — build, test and lint on every push
- [x] iOS app target, Today view with quick-add logging
- [x] SwiftData persistence behind a store protocol
- [x] Localisation — English (base), Ukrainian, Russian
- [ ] Onboarding flow
- [ ] Design system package — tokens for light, dark and custom themes
- [ ] Calendar and statistics screens
- [ ] Local notification reminders
- [ ] Home screen widget *(requires Apple Developer Program)*
- [ ] iCloud sync via SwiftData + CloudKit *(requires Apple Developer Program)*
- [ ] HealthKit step import *(requires Apple Developer Program)*

## Localisation

English, Ukrainian and Russian, with English as the source language.

Units are formatted by Foundation rather than assembled by hand. Writing
`"\(value) min"` would need "хв" in Ukrainian and "мин" in Russian, and would
still get plural forms and decimal separators wrong in both — 1.5 L is "1,5 л"
in both languages, with a comma. `MeasureFormatter` takes an injectable
`Locale` so tests pin a language rather than depending on the machine running
them.

Goal templates carry a *key*, not a word, so onboarding — the first thing
anyone sees — arrives in their own language.

> The Ukrainian and Russian strings were written without a native reviewer and
> are worth a second pair of eyes.

## Tooling

Swift 6.2 · Swift Testing · SwiftLint (`--strict` in CI) · swift-format · GitHub Actions
