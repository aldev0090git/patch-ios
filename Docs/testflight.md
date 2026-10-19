# Getting Patch onto TestFlight

Written while the Apple Developer Program enrolment was still pending, so the
steps below are in the order they will actually be needed.

## Before anything else

TestFlight needs a **paid Apple Developer Program membership** ($99/year). A
free Apple ID gives you a Personal Team, which signs builds onto *your own*
devices with a profile that expires after seven days — useful for testing on
real hardware, useless for sharing.

Enrol as an **Individual** unless there is a registered company: Organization
enrolment additionally needs a D-U-N-S number. The only practical difference is
that an Individual's legal name appears as the seller if the app is ever
published, and an app can be transferred to a company account later.

The usual cause of a stuck enrolment is the Apple ID's name not matching the
government ID exactly. Apple quotes 24–48 hours; outside the US it is routinely
longer. Past 48 hours, open a ticket with Apple Developer Support quoting the
Enrollment ID.

## Signing, without putting a team ID in the repository

`DEVELOPMENT_TEAM` is deliberately **unset** in `project.pbxproj`. That is what
lets anyone clone this repository and press Run — Xcode falls back to their own
Personal Team. Setting the team in Xcode's Signing & Capabilities tab writes the
ID into the project file and takes that away.

Keep it local instead:

```bash
# Signing.xcconfig — ignored by git
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Automatic
```

Then in Xcode: **Project → Info → Configurations**, set both Debug and Release
of the `Patch` target to use `Signing.xcconfig`. Add `Signing.xcconfig` to
`.gitignore` alongside `secrets.xcconfig`, and check the diff of
`project.pbxproj` afterwards — Xcode writes `DEVELOPMENT_TEAM` into the project
anyway if the team is ever picked from the Signing tab.

## Archive and upload

1. Bump `CURRENT_PROJECT_VERSION` — App Store Connect rejects a build number it
   has already seen, and this is the single most common upload failure.
   `MARKETING_VERSION` stays `1.0` until the app is actually released.
2. Xcode → **Product → Destination → Any iOS Device**, then **Product → Archive**.
3. In the Organizer: **Distribute App → TestFlight (and App Store)**.

`ITSAppUsesNonExemptEncryption` is set to `NO` in the build settings, so uploads
will not land in "Missing Compliance" and no export question is asked per build.
That is accurate: Patch does no networking and no cryptography of its own.

## App Store Connect

Create the app record once, against bundle ID `com.aldev0090.Patch`.

**App Privacy** is the easy part and worth doing honestly, because it is also
the app's best story: **Data Not Collected**, every category. No accounts, no
server, no analytics, no third-party SDKs, no tracking. Nothing leaves the
phone.

For TestFlight itself:

- **Internal testers** — up to 100, must be users on your App Store Connect
  team. No review; a build is available within minutes of processing.
- **External testers** — up to 10,000, invited by email or public link. They
  need nothing but the free TestFlight app. The **first build of each version
  train needs Beta App Review**; later builds of the same train do not.
- Builds **expire after 90 days**.

External testing also wants a beta app description and a feedback email before
review.

## What to ask testers for

Two things this project genuinely cannot check on its own:

- **The Ukrainian and Russian wording.** All 147 strings were written without a
  native reviewer, and two real bugs have already been found by looking at the
  running app rather than the catalog — a long-run target that read as
  money-only, and a picker that offered the same option twice. See the
  Localisation section of `CLAUDE.md`.
- **How the haptics feel.** Every one of them was written and merged against a
  simulator, which has none.

## Still open

**Landscape.** The build declares landscape support, but no screen was designed
for it and a UI-test rotation did not produce a usable landscape layout — the
window stayed portrait-shaped. That result is not trustworthy (driving rotation
from `XCUIDevice` is unreliable with SwiftUI), so this needs five seconds on a
real device before deciding between supporting it properly and locking the app
to portrait.
