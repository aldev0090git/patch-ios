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
| Don't smoke | `count` | `atMost` 0 | nothing — an empty day is a win |
| Save 100 UAH | `currency` | `atLeast` | one or more deposits |
| 10 000 steps | `count` | `atLeast` | filled in from HealthKit |

Adding a new kind of goal means adding a `MeasureKind`, not migrating the store
or branching the UI.

Two consequences fall out of this that are worth calling out:

**Abstinence is the absence of data.** "Don't smoke" is `atMost 0`, so a day with
no entries already succeeds. You only log when you slip — less work for the user,
and more honest than asking them to tick a box every evening.

**Amounts are always stored in a canonical unit** — seconds, millilitres, metres.
Display units are a presentation concern. Totals, comparisons and (later) sync
never have to care how a number was entered.

## Architecture

```
Packages/PatchKit/          Pure Swift. No SwiftUI, no SwiftData, no UIKit.
  Sources/PatchCore/
    Measure.swift           What a goal asks of a day
    Schedule.swift          Which days it asks on
    Goal.swift              The goal itself
    Entry.swift             One logged contribution
    DayProgress.swift       How one goal stands on one day
    ProgressCalculator.swift
    StreakCalculator.swift
  Tests/PatchCoreTests/     23 tests, run in ~2ms, no simulator needed

App/                        SwiftUI app target (in progress)
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

## Getting started

Requires Xcode 27 or later.

```bash
git clone git@github.com:aldev0090git/patch-ios.git
cd patch-ios

# Domain layer — no Xcode project needed
cd Packages/PatchKit
swift test
```

## Roadmap

- [x] Domain model — measures, schedules, progress, streaks
- [x] Unit test suite
- [x] CI — build, test and lint on every push
- [ ] SwiftData persistence behind a repository protocol
- [ ] Today view with quick-add logging
- [ ] Design system package — tokens for light, dark and custom themes
- [ ] Calendar and statistics (month, year, custom ranges)
- [ ] Local notification reminders
- [ ] Localisation — English (base), Ukrainian, Russian
- [ ] Home screen widget *(requires Apple Developer Program)*
- [ ] iCloud sync via SwiftData + CloudKit *(requires Apple Developer Program)*
- [ ] HealthKit step import *(requires Apple Developer Program)*

## Tooling

Swift 6.2 · Swift Testing · SwiftLint (`--strict` in CI) · swift-format · GitHub Actions
