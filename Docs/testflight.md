# Getting Patch onto TestFlight

**Done — Patch has been on TestFlight since 20 October 2026.** What follows is
what was actually required, kept because every step of it has to be repeated
for each new build, and because the parts that were not obvious are the parts
that cost time.

Public link: `https://testflight.apple.com/join/W2KmuhsA`

## Before anything else

TestFlight needs a **paid Apple Developer Program membership** ($99/year). A
free Apple ID gives you a Personal Team, which signs builds onto *your own*
devices with a profile that expires after seven days — useful for testing on
real hardware, useless for sharing.

**Enrol on the web**, at `developer.apple.com/programs/enroll/`. The in-app
purchase route — Xcode, or the Apple Developer app — is refused for a Ukrainian
Apple Account with *"This item is currently not available in your
country/region"*. That is a storefront limit on the subscription, not a
restriction on the programme: Ukraine is a supported territory, and the web
purchase went through immediately. Activation took hours, not the two business
days quoted.

Enrol as an **Individual** unless there is a registered company: Organization
enrolment additionally needs a D-U-N-S number. The only practical difference is
that an Individual's legal name appears as the seller if the app is ever
published, and an app can be transferred to a company account later.

The usual cause of a stuck enrolment is the Apple ID's name not matching the
government ID exactly. Apple quotes 24–48 hours; outside the US it is routinely
longer. Past 48 hours, open a ticket with Apple Developer Support quoting the
Enrollment ID.

## What has to exist before a build can be uploaded

1. An **explicit App ID** at *Certificates, Identifiers & Profiles* —
   `com.aldev0090.Patch`, matching case exactly. Xcode's wildcard team profile
   is not enough; App Store Connect will not offer the bundle ID without it.

   **Capabilities, as they were added:** App Groups (for the widget's shared
   snapshot) and HealthKit. Tick **HealthKit**, not *HealthKit Estimate
   Recalibration* — that is a narrow entitlement for apps correcting Apple's
   own VO2 max estimates with their own hardware. Adding a capability
   **invalidates existing provisioning profiles**; Xcode regenerates them, but
   a signing error on the next archive is why.
2. An **app record** in App Store Connect. The name must be unique across the
   whole App Store — "Patch" was taken, hence **Patch: Habit Tracker**. The
   name under the icon on the home screen is unaffected; that comes from the
   bundle display name.
3. **Test Information** filled in: feedback email, a beta description, contact
   details, and review notes. Say *"no account or sign-in is needed"* — an
   app a reviewer cannot get into is the usual cause of a rejection.

## Signing, without putting a team ID in the repository

`DEVELOPMENT_TEAM` is deliberately **unset** in `project.pbxproj`. That is what
lets anyone clone this repository and press Run — Xcode falls back to their own
Personal Team. Setting the team in Xcode's Signing & Capabilities tab writes the
ID into the project file and takes that away.

Keep it local instead:

This is already wired up. `Patch/Signing.xcconfig` is committed and holds only
an *optional* include; the team lives in `Patch/Signing.local.xcconfig`, which
is gitignored:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Because the include is `#include?`, a fresh clone with no local file builds for
the simulator with no team, no warning and no error — which is all anyone
reading the code needs.

**Watch the diff.** Picking a team in Xcode's Signing & Capabilities tab writes
`DEVELOPMENT_TEAM` back into `project.pbxproj` regardless. If it appears there,
move it to the local xcconfig and revert the project file.

## Archive and upload

1. Bump `CURRENT_PROJECT_VERSION` — App Store Connect rejects a build number it
   has already seen, and this is the single most common upload failure.
   `MARKETING_VERSION` stays `1.0` until the app is actually released.
2. Xcode → **Product → Destination → Any iOS Device**, then **Product → Archive**.
   Archive is greyed out on a simulator destination.
3. In the Organizer: **Distribute App → App Store Connect**.

   **Not "TestFlight Internal Only".** That marks the build internal-only for
   ever: it can never reach external testers or the App Store, and the fix is
   to archive and upload again. "App Store Connect" covers internal testing,
   external testing and release from the one build.

`ITSAppUsesNonExemptEncryption` is set to `NO` in the build settings, so uploads
will not land in "Missing Compliance" and no export question is asked per build.
That is accurate: Patch does no networking and no cryptography of its own.

## App Store Connect

Create the app record once, against bundle ID `com.aldev0090.Patch`.

**App Privacy** is the easy part and worth doing honestly, because it is also
the app's best story: **Data Not Collected**, every category. No accounts, no
server, no analytics, no third-party SDKs, no tracking. Nothing leaves the
phone.

Reading Apple Health does **not** change that answer. Apple defines collection
as transmitting data off the device; Patch reads a daily total, writes it into
its own local store and sends it nowhere. It stays "Data Not Collected".

It does, however, require a **privacy policy URL** — App Review guideline 5.1.3
makes one mandatory for any app that accesses HealthKit. TestFlight does not
check for it; submission does. The text is in `Docs/privacy-policy.md` and
needs to be served somewhere public, with a contact address filled in, before
the app is submitted.

For TestFlight itself:

- **Internal testers** — up to 100, must be users on your App Store Connect
  team. No review; a build is available within minutes of processing.
- **External testers** — up to 10,000, invited by email or public link. They
  need nothing but the free TestFlight app. The **first build of each version
  train needs Beta App Review**; later builds of the same train do not.
- Builds **expire after 90 days**.

External testing also wants a beta app description and a feedback email before
review, and a **public link** is far easier than collecting addresses — anyone
with the URL installs through TestFlight. Set a tester limit on it: a public
link really is public, and a cap is the only thing between a link that leaks
and a support burden.

Watch for one thing in the external flow: the **"Sign-in required"** box comes
up ticked by default. Patch has no sign-in, so untick it, or the form demands
credentials that do not exist and will not let you continue.

## What to ask testers for

Two things this project genuinely cannot check on its own:

- **The Ukrainian and Russian wording.** All 147 strings were written without a
  native reviewer, and two real bugs have already been found by looking at the
  running app rather than the catalog — a long-run target that read as
  money-only, and a picker that offered the same option twice. See the
  Localisation section of `CLAUDE.md`.
- **How the haptics feel.** Every one of them was written and merged against a
  simulator, which has none.

## Settled on a real device

All three of the things that could only be judged on hardware have been:

- **Haptics** feel right. They had every one of them been written against a
  simulator with no Taptic Engine.
- **Landscape** works. The header now adapts to a compact height rather than
  taking 40% of the screen.
- **VoiceOver** works.
- **Apple Health** works, including the part no test could reach. HealthKit is
  unavailable to a simulator in any useful sense — the framework is there but
  there is no data — so the import was verified by hand on 20 October, by
  typing step samples into the Health app and watching Patch:

  | Health says | Patch shows |
  | --- | --- |
  | 1 000 | 1 000 |
  | 1 500 (+500) | **1 500**, not 2 500 |
  | 1 500, plus 2 000 logged by hand in Patch | **3 500** |
  | after backgrounding, and after a full relaunch | **3 500** |

  The second row is the one that matters: the import added only the 500 that
  was new. The fourth is the other half — a hand-logged entry is not absorbed
  by the next refresh. Health stayed at 1 500 throughout, because Patch never
  writes.

  Two things behaved as designed and look like bugs if you do not expect them:
  a goal created today does **not** backfill earlier days, even where Health
  has them, and a day Health knows nothing about imports nothing rather than
  importing a zero.
