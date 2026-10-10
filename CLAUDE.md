# Patch — working notes

Conventions for this repository. Read before making changes.

## What this app is

A goal and habit tracker. Every goal is the same shape: **an amount accumulated
toward a daily target, in a direction** (`atLeast` / `atMost`). Reading minutes,
push-ups, millilitres of water, money saved, cigarettes not smoked and steps are
all that one model. Do not special-case goal types — if something cannot be
expressed as a measure plus a direction, that is a design discussion, not a
reason to branch.

**Patch records what you did, never what you avoided.** Every goal is something
to complete and mark. Do not reintroduce "log a slip"-style interactions: a
button that fails the user's own goal, on a row already showing a tick, confused
every person who saw it. Goals that would naturally be "stay at zero" are
modelled as a daily confirmation instead — see `GoalTemplateCatalog.quitSmoking`.

`LoggingStyle` decides the controls a goal gets: `.incremental` for amounts that
add up, `.single` for once-a-day. It lives in the domain because it follows from
the goal's shape, not from a view's preference.

## Hard rules

- **`PatchCore` imports `Foundation` and nothing else.** No SwiftUI, no
  SwiftData, no UIKit, ever. If domain logic seems to need them, the logic is in
  the wrong layer.
- **Amounts are stored in canonical units**: seconds, dimensionless counts,
  millilitres, metres, major currency units. Conversion happens at the edges.
  Use the `Measure` convenience constructors rather than writing `* 60` inline.
- **Money uses `Decimal`, never `Double`.** `Decimal.doubleValue` exists for
  display maths only (ring fractions) and must never feed a stored total.
- **Inject `Calendar`.** Never reach for `.current` inside domain code.
- **Entries are immutable once created** — add or remove them, never edit an
  amount in place. That keeps sync conflict-free at the field level.
  - Undoing a mistap **deletes** the entry. A tap made by accident is not
    history worth keeping, and users expect undo to undo.
  - Correcting a day you genuinely over-reported uses a **negative entry**, so
    the original record survives and the day's total stays auditable.
- **Soft-delete via `archivedAt`.** Hard deletion will fight CloudKit later.

**Do not leave unused properties on a persisted model.** `GoalTint` and
`Measure.quickAdd` were both written, stored and never read; both were removed
rather than left in place. A field nobody uses still becomes a column, and once
CloudKit is on, removing a column is a migration rather than a refactor.

## Models must stay CloudKit-compatible

Sync is not switched on yet (it needs the paid Apple Developer Program) but the
schema is already designed for it. When SwiftData models arrive:

- every property optional or with a default
- no `@Attribute(.unique)`
- every relationship has an inverse

Breaking these is cheap today and a migration later.

## Localisation

Three languages: English (source), Ukrainian, Russian. All user-facing strings
live in `Patch/Patch/Localizable.xcstrings`.

- **`Text("literal")` localises. `Text(someString)` does not.** This is the easy
  mistake here and it fails silently: passing a literal through a `String`
  parameter shipped "Manual" and "Done" in English while the rest of the screen
  translated. Helpers take `Text`, so each caller has to say which it means.
- Already-formatted amounts go through **`Text(verbatim:)`** so they are never
  looked up as a key.
- Outside a view, use **`String(localized:)`** — a bare `String` return value
  handed to `Text` will not be translated.
- **Never hand-assemble units.** `MeasureFormatter` uses Foundation's
  measurement and duration formatting, which already knows "хв", "мин", plural
  forms, and that 1.5 L is "1,5 л" in both other languages.
- Goal templates carry a `titleKey`, never an English word.

## Testing

- **Swift Testing**, not XCTest. `@Suite` / `@Test` / `#expect`.
- Test names are sentences describing behaviour, not method names.
  Good: `"Today still being unfinished does not wipe out the streak"`.
  Bad: `testCurrentStreak2`.
- Domain tests use `fixedCalendar()` and `day(_:_:_:)` from `TestSupport.swift`.
  Never use `Date()` or `.current` in a test.
- Run with `cd Packages/PatchKit && swift test`. Should stay under a second.

## Style

- SwiftLint runs `--strict` in CI, so **warnings fail the build**. Fix them.
  If a rule genuinely should not apply, disable it for the narrowest possible
  scope with a comment saying why — never loosen it repo-wide.
- Comments explain *why*, not *what*. The existing domain files are the
  reference for tone and density; match them.
- SF Symbols for iconography, system materials and standard controls by default.
  The app should feel native before it feels custom.

## CI costs real minutes

macOS runners bill at a **10x multiplier**, so the free tier is roughly 200
usable minutes a month on a private repo. Keep the SPM cache working, keep
`concurrency.cancel-in-progress` on, and do not add simulator-based UI tests to
every-push CI without a reason.

## Project shape

`.xcodeproj` is committed deliberately, so anyone can clone and hit Run with no
extra tooling. That is a portfolio requirement — do not replace it with Tuist or
XcodeGen.

**The project is in Xcode 27's native format (`objectVersion = 110`), so Xcode 27
or later is required to open it.** We tried pinning it to 77 for wider
compatibility, but Xcode silently rewrites the format every time the project is
opened, which broke CI repeatedly. Fighting the IDE on every save cost more than
the compatibility was worth. Let Xcode manage this field.

**Do not "select the newest Xcode" on a runner.** The `xcode-27` image ships
betas alongside the release, and picking the highest version selects a beta,
so builds can fail on beta bugs instead of on this code. Use the image default.

The app's deployment target is **iOS 26.0**, matching PatchKit's platform floor.
Xcode's template defaults to the newest OS, which would exclude every 26.x
simulator and almost every real device.
