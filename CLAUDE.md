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
- Goal templates carry a `titleKey`, never an English word, and the key
  **travels onto the goal** (`Goal.titleKey`). Titles are resolved at *display*
  time by `Goal.localizedTitle`. Resolving once at creation and saving the word
  froze every seeded goal into whichever language launched first, which is how
  a Russian reader ended up with "Don't smoke" among Russian text. Renaming a
  goal clears the key: a name the user typed is theirs and must not be
  translated out from under them.
- **`xcodebuild` does not write new keys into the catalog** — only the Xcode IDE
  merges them. Working from the command line, read the extracted keys out of
  `DerivedData/Patch-*/Build/Intermediates.noindex/Patch.build/*/Patch.build/Objects-normal/arm64/*.stringsdata`
  (JSON despite the name; `tables` maps a table name to a **list** of
  `{key, location}`) and add them to `Localizable.xcstrings` directly. Check
  the diff of extracted-vs-catalog keys rather than trusting a build to have
  noticed, and **confirm the files are newer than your edit** — a stale
  `stringsdata` reports every removed key as still in use. The parallel tree
  under `DerivedData/Patch-*/Localization/Strings/` is the IDE's and is not
  refreshed by `xcodebuild`.
- **A translation can be correct and still wrong.** "Overall goal / Work toward
  a total" is measure-neutral in English; the Russian said "Копить до суммы"
  ("save up to a sum"), which made a feature that also covers 1000 km and 100
  hours look like it was only for money. And two segments of one control
  translated to strings that both truncated to "Определённы…", so the picker
  offered the same option twice. Look at the screen in each language.
- The Ukrainian and Russian strings are **unreviewed by a native speaker**. Say
  so when handing work over.

## Testing

- **Swift Testing**, not XCTest. `@Suite` / `@Test` / `#expect`.
- Test names are sentences describing behaviour, not method names.
  Good: `"Today still being unfinished does not wipe out the streak"`.
  Bad: `testCurrentStreak2`.
- Domain tests use `fixedCalendar()` and `day(_:_:_:)` from `TestSupport.swift`.
  Never use `Date()` or `.current` in a test.
- Run with `cd Packages/PatchKit && swift test`. Should stay under a second.
- App tests: `xcodebuild test -only-testing:PatchTests`. Swift Testing results
  do not show up in `xcodebuild`'s console output — pass `-resultBundlePath` and
  read the count with `xcrun xcresulttool get test-results summary`.
- **UI tests are deliberately out of CI** (`PatchUITests` is never in
  `-only-testing`). They need a simulator and cost 10x minutes. They exist to
  catch what unit tests cannot — a screen that renders empty, a tab that never
  appears — and they attach screenshots, which `xcrun xcresulttool export
  attachments` pulls out. **Run them and look at the result** before calling a
  screen done; every UI bug so far was found by looking, not by reading code.

## Style

- SwiftLint runs `--strict` in CI, so **warnings fail the build**. Fix them.
  If a rule genuinely should not apply, disable it for the narrowest possible
  scope with a comment saying why — never loosen it repo-wide.
- Comments explain *why*, not *what*. The existing domain files are the
  reference for tone and density; match them.
- SF Symbols for iconography, system materials and standard controls by default.
  The app should feel native before it feels custom.
- **An empty state is not a zero.** A window where nothing has settled yet has
  no completion rate; showing "0%" claims a verdict that has not been reached,
  and colouring it green makes it worse. Unsettled states show an em dash, say
  why in words, and sort below the rows that do have a record. This was got
  wrong twice on the same screen.
- Types used by a `nonisolated` helper, or by tests, must themselves be
  `nonisolated`. The app target defaults to MainActor isolation, so a plain
  `struct` is MainActor-isolated and unusable from a test.

## Changing a goal must not rewrite its past

A day is judged against `goal.dailyTarget(on:)`, never `measure.dailyTarget`.
Raising "read 20 minutes" to an hour once turned every finished day behind it
into a failure. `measure.dailyTarget` is only ever the *current* target — for
quick-add suggestions, the manual picker and the editor. Anything that looks
at a past day goes through the history.

Changing the measure *kind* deliberately clears that history: 1200 seconds and
1200 push-ups are not comparable numbers.

## A goal card has exactly one height

Both halves of `GoalCard` are always laid out, one of them transparent, so a
done card is exactly as tall as an unfinished one. **Do not replace that with a
conditional.** When the height changed, `UITableView` animated the row height
underneath SwiftUI — scaling the row's content, so the card came out taller
*and wider* and drew across its neighbour, because `List` does not clip rows.
Four SwiftUI-level fixes failed before the cause was found, because none of
them reach that animation. `GoalCardHeightUITests` pins the invariant by
watching the card below.

## Theming: `Color.accentColor` is not the accent

`Color.accentColor` reads the **asset catalog** and ignores `.tint(_:)`, so a
view using it stays blue while the rest of the app changes colour. The app sets
both `.tint(_:)` and `\.themeAccent` once, at the top of `RootView`:

- controls, `.foregroundStyle(.tint)` and `AnyShapeStyle(.tint)` follow `.tint`
- anything needing the accent as a **value** — a fill, an opacity, a stroke —
  reads `@Environment(\.themeAccent)`

Both go **outside** the presentation modifiers. A sheet inherits the environment
of the view its modifier is attached to, so a tint applied further in stops at
the onboarding cover.

**`Color.goalDone` and `Color.goalMissed` are not themed, deliberately.** Done
and missed are states, not decoration; if they followed the accent, the same
card would read green-for-finished under one theme and green-for-in-progress
under another. That is also why `AccentTheme` offers no green — see the doc
comment on it before adding a colour.

## iOS schedules at most 64 local notifications per app

Anything that plans notifications has to have a ceiling it cannot cross, and a
test for it. Per-goal reminders had neither: one request per day a goal ran on
meant ten weekday goals asked for seventy, iOS kept the 64 soonest, and the
rest were dropped with no error — reminders that simply never arrived.

Reminders are now **whole-app check-ins**, capped at `DailyCheckIns.maximum`.
Do not reintroduce a per-goal reminder, and do not raise that cap without
working out the worst case.

## Apple Health fills goals in; it does not own them

A goal carries an optional `healthSource`, set by the user in the editor. It is
an explicit choice rather than an inference because **the domain cannot tell a
step goal from a push-up goal** — both are `MeasureKind.count`, deliberately,
and nothing about "10 000" says a phone can count it. Matching on a template id
or a title would break the moment someone renames their goal, which the app
invites them to do.

- **The units already line up.** Patch stores counts dimensionless, distance in
  metres, duration in seconds; HealthKit's SI units for these are `count()`,
  `meter()` and `second()`. There is no conversion in this feature. A factor
  appearing in `HealthKitReader.unit(for:)` means a measure kind has drifted
  from its stored unit — fix that, not the reader.
- **Imports are deltas, not totals.** Entries are immutable and Health's figure
  for today climbs all day, so `HealthImportPlanner` writes the difference
  between what Health says and what this goal has *already imported*. That is
  what `Entry.source` is for: without it the planner would have to subtract the
  whole day's total and would silently swallow anything logged by hand. Manual
  and imported amounts add up, which is the honest reading of "I did both".
- **A negative delta is correct**, not a bug. Deleting a workout in the Health
  app lowers the day, and a goal that stayed high would claim something the
  user has just said did not happen.
- **Read permission cannot be queried.** `authorizationStatus(for:)` reports
  *write* access only; Apple hides whether a read was refused, because "this
  app knows you declined" is itself a disclosure. A refusal is indistinguishable
  from a day with no data. So nothing in the app claims a goal is connected —
  the editor footer says where to look instead. (`statusForAuthorizationRequest`
  *is* answerable, but only says whether the question has been put — which
  `requestAuthorization` already handles by not re-prompting, so it is not
  worth keeping a wrapper for.)
- Import runs on appear and on every return to the foreground, guarded by
  `TodayModel.isImporting`: launch and the first `scenePhase` change would
  otherwise both read the same entries before either had written.

### Entitlements are not checked by a simulator build

HealthKit needs exactly one entitlement: `com.apple.developer.healthkit`.
`com.apple.developer.healthkit-access` is for **clinical health records** only,
and an empty `<array/>` for it fails provisioning outright — *"Entitlement
com.apple.developer.healthkit-access not found and could not be included in
profile"*. It was added here by mistake and had to come out.

Nothing caught it, because **a simulator build does not validate entitlements
against a provisioning profile** — it builds and runs regardless. Only a
signed build for a device does. So after touching `Patch.entitlements`, a
green simulator build and a green CI run mean nothing: the check is Xcode's
Signing & Capabilities tab with a real device selected.

### The simulator does have HealthKit

`Health.app`, `HealthKit.framework` and `HealthKitUI.framework` all ship in the
iOS simulator runtime, and `isHealthDataAvailable()` is true there, so
`HealthLinkUITests` can check that the editor row appears and disappears with
the chosen measure. What the simulator has no sensors for is *data* — add
samples by hand in its Health app, or test the numbers on a phone. The policy
is covered without either, in `HealthImportTests`.

## Haptics are imperative, not `.sensoryFeedback`

Every event in `Haptics` acknowledges something the user *just did*, so it goes
in the action that did it. `.sensoryFeedback(trigger:)` fires on any change to
the value it watches, including the one the store makes when a screen first
loads — a day already logged would buzz the phone on launch, and a reset would
be indistinguishable from a log because both move the same number.

Pick the event by comparing state **before and after** the write, never from the
amount: finishing is a transition. `Haptics.isEnabled` reads `UserDefaults`
directly so no call site has to carry the setting; absent means on.

## Running the simulator from the command line

- The simulator wedges into `Busy ("Application failed preflight checks")`
  after repeated runs. Terminate **both** `com.aldev0090.Patch` and
  `com.aldev0090.PatchUITests.xctrunner` and wait a few seconds between runs.
- **`simctl io recordVideo` causes that state outright** — it blocks app
  launches entirely. Capture frames with screenshot attachments from inside the
  test instead, or `XCUIScreen.main.screenshot()` in a loop.
- `XCUITest` waits for animations to settle before `tap()` returns, so
  screenshots taken straight after a tap only ever catch the settled state.
- Tapping a `Toggle` row in a `Form` lands on the row and does not reliably
  flip it. Tap the switch end:
  `toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()`.
- To check a translation in place, run `ScreenshotUITests` with
  `TEST_RUNNER_PATCH_UI_LANGUAGE=ru`. A plain shell variable does not reach the
  runner — it runs on the simulator — but `xcodebuild` forwards anything
  prefixed `TEST_RUNNER_`, with the prefix stripped. Such a run must query by
  **accessibility identifier**, never by label: the labels are translated.
- **`xcodebuild` writes into the same DerivedData the user's Xcode uses.** A
  command-line build, a `touch` of the sources to force string re-extraction,
  or deleting anything under `DerivedData/Patch-*` invalidates the open Xcode's
  incremental state, and it then reports errors for symbols that exist — "Cannot
  find 'Haptics' in scope", "Type 'Color' has no member 'goalMissed'" — which
  cost a round trip to diagnose. Prefer `-derivedDataPath` somewhere scratch for
  anything other than a quick check, and if the user reports phantom errors,
  confirm with a clean build in an isolated path before touching their code.
- Never drive a simulator the user has Xcode pointed at. Shutting one down
  under a live debug session leaves a stale `lldb-rpc-server` and a wedged
  DeviceHub, and Xcode then hangs on Replace and Stop.

## The shared scheme keeps picking up a language

Xcode rewrites `Patch.xcscheme` with whatever App Language the Run action is
set to, so testing translations commits `language = "ru"` and every clone then
launches in Russian. Check for it in diffs; the real fix is setting App Language
back to "System Language" in Edit Scheme.

## Lint scope

`.swiftlint.yml` `included:` must name **`Patch`** and **`Packages`**. It said
`App` — a directory that does not exist — for the project's first 25 commits,
so the lint job passed while silently checking none of the app's source. If the
file count in SwiftLint's output drops, that is the bug.

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
