# Patch

A goal and habit tracker for iPhone, built in SwiftUI.

Reading twenty minutes a day, a hundred push-ups, two litres of water, money put
aside when the salary lands, a day without smoking — Patch treats all of these as
the same thing, and that single idea shapes the whole codebase.

| Today | Calendar | Statistics |
|---|---|---|
| ![Today](Docs/screenshots/today.png) | ![Calendar](Docs/screenshots/calendar.png) | ![Statistics](Docs/screenshots/statistics.png) |

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
| Save 4 000 UAH | `currency` | `atLeast` | on the 1st and the 15th |
| 10 000 steps | `count` | `atLeast` | filled in from HealthKit *(planned)* |

Adding a new kind of goal means adding a `MeasureKind`, not migrating the store
or branching the UI.

Three consequences fall out of this that are worth calling out.

**Patch records what you did, never what you avoided.** "Don't smoke" was first
modelled as `atMost 0`, so a day with no entries already succeeded and the only
available action was admitting a slip — a button that undoes the user's own
goal, sitting on a row already marked complete. It now works like any other
once-a-day goal: you confirm it. The tick means you actually said so, rather
than meaning the clock has not caught you yet.

**Amounts are always stored in a canonical unit** — seconds, millilitres,
metres. Display units are a presentation concern. Totals, comparisons and
(later) sync never have to care how a number was entered. Money is the one
exception, because 100 is a different amount in dollars, euros and hryvnia, so
a currency goal carries an ISO code alongside it.

**Changing a goal never rewrites its past.** Raising "read 20 minutes" to an
hour used to turn every finished day behind it into a failure, because progress
judged the whole history against whatever the target happened to be now. A goal
keeps the targets it has had and the day each took effect, and every day is
judged against the one that was actually in force.

## Architecture

```
Packages/PatchKit/
  Sources/PatchCore/        Pure Swift. No SwiftUI, no SwiftData, no UIKit.
    Measure.swift           What a goal asks of a day, and in what unit
    Schedule.swift          Which days it asks on — daily, weekdays, or dates
    Goal.swift              The goal itself
    TargetHistory.swift     What it asked for on any given day
    Entry.swift             One logged contribution
    Reminder.swift          A time of day, not an instant
    DayProgress.swift       How one goal stands on one day
    ProgressCalculator.swift
    StreakCalculator.swift
    CumulativeProgress.swift  Long-run targets: "save 60 000 by March"
    QuickAdd.swift          Suggested one-tap logging amounts
    ManualAmounts.swift     The picker's range, when one tap is not enough
    Statistics.swift        Done/missed over day, week, month, year, custom
    GoalTemplate.swift      Ready-made goals for onboarding
    GoalStore.swift         The persistence contract, plus an in-memory store
  Sources/PatchStore/       The only place that imports SwiftData
  Tests/                    124 tests, ~30 ms, no simulator needed

Patch/                      SwiftUI app target — 103 unit tests
  Patch/Localizable.xcstrings   English, Ukrainian, Russian
  PatchUITests/             Simulator tests, deliberately out of CI
```

The domain layer imports nothing but `Foundation`. That is the point: all the
logic worth testing — progress, clamping, streaks, schedules, target history,
corrections — is testable in milliseconds without booting a simulator, and
persistence can be swapped without touching any of it.

**Calendars are injected, never global.** `ProgressCalculator` and
`StreakCalculator` take a `Calendar`, so tests pin UTC and a Monday
first-weekday and behave identically on a laptop in Kyiv and a CI runner
elsewhere.

**Entries are append-only in spirit.** Correcting a mistake adds a negative
amount rather than mutating history, which keeps a day's total auditable and
avoids edit conflicts once CloudKit sync is enabled.

**The store is CloudKit-shaped from the first commit** — every property
defaulted or optional, no unique constraints, no relationships; goals and
entries are linked by `goalID`. Turning sync on is meant to be a capability
checkbox rather than a migration.

### Product rules encoded in the domain

Deliberate, documented and tested, because each of them is a decision rather
than an implementation detail:

- **Unscheduled days are skipped, not failed.** A weekday-only gym habit keeps
  its streak across the weekend.
- **Today is forgiving.** If today is scheduled but not yet done, the streak is
  measured from yesterday rather than displayed as zero. Resetting someone's
  streak at 00:01 punishes them for the clock, not their behaviour.
- **"Missed" means genuinely missed.** Statistics exclude days before the goal
  was created, days still in the future, and an unfinished today. Without this,
  every new goal opens on a wall of red for a month it was never set during.
- **A rate of 0% is not the same as no data.** A window where nothing has
  settled yet shows a dash, not a confident zero.
- **A date the month does not have falls on its last day.** Someone paid on the
  31st is still paid in February. Skipping would be invisible — an unscheduled
  day does not even break a streak.

### Logging should take one tap, and fit the goal

A goal's shape decides how it is logged, so the domain exposes a `LoggingStyle`
rather than leaving the view to guess: goals that accumulate get a row of
amounts, goals that happen once a day get a single **Done** button.

Suggested amounts scale with the target and snap to round numbers people
actually say:

| Goal | Suggestions |
|---|---|
| Read 20 minutes | 5 min · 10 min · 20 min |
| 100 push-ups | 25 · 50 · 100 |
| 2 litres of water | 500 ml · 1 L · 2 L |
| 10 000 steps | 2 000 · 5 000 · 10 000 |

Three, plus **Manual** for anything else — four equal slots, so every goal's
controls line up down the screen rather than each row finding its own rhythm.

**A goal card is exactly as tall when it is done as when it is not.** Both
halves are always laid out, one of them transparent. That is not a styling
choice: when the height changed, `UITableView` animated the row height
underneath SwiftUI and the card drew across its neighbour, because `List` does
not clip rows. A constant height makes the bug impossible rather than
suppressed, and the space a finished card was wasting now carries its streak.

### Long-run goals

A daily target answers "what should I do today". Some goals also need "where am
I heading" — save 60 000 by March, read a hundred hours this year. Those are
tracked separately from the daily rhythm, with an optional date.

![Long-run goal](Docs/screenshots/long-run-goal.png)

Reaching the target early and then letting the date pass is a success, not a
failure. Once a date has gone, no per-day figure is offered, because none of
them rescues it.

## Onboarding

| Choose what to track | How it works |
|---|---|
| ![Choosing goals](Docs/screenshots/onboarding.png) | ![How it works](Docs/screenshots/how-it-works.png) |

Three preselected, because an empty list asks someone who has just opened the
app to invent their own habits before they know what it does. Picking none is
allowed — someone who wants to write their own should not have to untick a
decoy first. The last page covers the three things that cannot be discovered by
looking: tap to log, swipe left to reset or archive, swipe right to edit.

## There are no accounts, deliberately

Patch has no sign-in screen, no password, and no server.

Syncing is planned through **CloudKit's private database**, which is not a
login: the user is already signed into iCloud, so their goals reach a new
iPhone without an account system existing at all. No credentials to lose, no
recovery flow to build, and no one else's habit data on anybody's server.

A third-party login like Google would only buy something if there were a backend
to talk to, and there isn't one — it would mean building and paying for a
server, and becoming the data controller for other people's personal routines,
to deliver what CloudKit gives for free. The one thing that would change this
is an Android version, since CloudKit does not exist there.

## Getting started

```bash
git clone git@github.com:aldev0090git/patch-ios.git
cd patch-ios

# Run the app
open Patch/Patch.xcodeproj

# Or just the domain layer — no Xcode project needed
cd Packages/PatchKit && swift test
```

Requires **Xcode 27 or later** to open the project. The app targets **iOS 26.0**
and **iPhone only** — the Xcode template's multiplatform defaults were removed,
because nothing here has ever been built or designed for a Mac or an iPad.

The app icon is generated rather than committed as an opaque binary:

```bash
swift Tools/make-app-icon.swift Patch/Patch/Assets.xcassets/AppIcon.appiconset
```

The screenshots above come from `ScreenshotUITests`, which launches the app with
a `-demo-data` argument. The seeder behind it is `#if DEBUG` only and cannot
reach a release build.

## Roadmap

- [x] Domain model — measures, schedules, progress, streaks, target history
- [x] Quick-add suggestion engine and manual entry
- [x] Statistics — done/missed over day, week, month, year, custom ranges
- [x] SwiftData persistence behind a store protocol
- [x] Today, Calendar and Statistics screens
- [x] Create, edit and archive goals
- [x] Onboarding from goal templates
- [x] Local notification reminders, following each goal's own schedule
- [x] Currencies, dates-of-month schedules, long-run targets
- [x] Localisation — English (base), Ukrainian, Russian
- [x] CI — build, test and lint on every push
- [x] App icon
- [ ] Custom themes beyond system light and dark
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

Goal templates carry a *key*, not a word, and the key travels onto the goal, so
a seeded goal still follows the phone's language months later. Renaming a goal
clears the key — a name someone typed is theirs, and translating it out from
under them would be wrong.

> The Ukrainian and Russian strings were written without a native reviewer and
> are worth a second pair of eyes.

## Tooling

Swift 6.2 · Swift Testing · SwiftLint (`--strict` in CI) · GitHub Actions
