# Patch — working notes

Conventions for this repository. Read before making changes.

## What this app is

A goal and habit tracker. Every goal is the same shape: **an amount accumulated
toward a daily target, in a direction** (`atLeast` / `atMost`). Reading minutes,
push-ups, millilitres of water, money saved, cigarettes not smoked and steps are
all that one model. Do not special-case goal types — if something cannot be
expressed as a measure plus a direction, that is a design discussion, not a
reason to branch.

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
- **Corrections are negative entries.** Never mutate or delete history to fix a
  number.
- **Soft-delete via `archivedAt`.** Hard deletion will fight CloudKit later.

## Models must stay CloudKit-compatible

Sync is not switched on yet (it needs the paid Apple Developer Program) but the
schema is already designed for it. When SwiftData models arrive:

- every property optional or with a default
- no `@Attribute(.unique)`
- every relationship has an inverse

Breaking these is cheap today and a migration later.

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

**Keep `objectVersion = 77` in project.pbxproj.** Not for CI any more — the app
job runs on the `xcode-27` image and matches local Xcode exactly. It is so the
repo opens in Xcode 16 and later. Format 110 would restrict it to Xcode 27,
which defeats the purpose of committing the `.xcodeproj` for clone-and-Run.
If Xcode offers to upgrade the project format, decline; CI enforces this.

**Do not "select the newest Xcode" on a runner.** The `xcode-27` image ships
betas alongside the release, and picking the highest version selects a beta,
so builds can fail on beta bugs instead of on this code. Use the image default.

The app's deployment target is **iOS 26.0**, matching PatchKit's platform floor.
Xcode's template defaults to the newest OS, which would exclude every 26.x
simulator and almost every real device.
