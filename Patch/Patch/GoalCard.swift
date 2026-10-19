import PatchCore
import SwiftUI

/// One goal, as a card.
///
/// Two separate signals, deliberately not duplicating each other: the ring
/// carries *how far along today is*, and the card's background carries *what
/// state the day is in* — plain while it is running, green once it is done.
/// Filling the background by fraction instead made a part-finished card look
/// split in two rather than partly filled.
struct GoalCard: View {
    let goal: Goal
    let progress: DayProgress
    let streak: Int
    let onLog: (Decimal) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.themeAccent) private var themeAccent

    /// Scaled so the ring and the tick grow with the text rather than shrinking
    /// into a corner of it. A fixed 44pt circle beside accessibility-sized type
    /// looks like a rendering bug.
    @ScaledMetric(relativeTo: .headline) private var ringSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title3) private var statusIconSize: CGFloat = 30

    @State private var isEnteringManually = false

    /// Equal columns, so controls line up across every card no matter how many
    /// a goal needs.
    ///
    /// Halved at accessibility text sizes. Four columns still fit there, but
    /// only by shrinking the labels below the size the user asked for, which
    /// defeats the point of asking. Two columns let the text render at full
    /// size and wrap to a second row instead.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    /// Done and missed are states and keep their own colours whatever the
    /// theme is; a goal still running takes the accent. That is also why the
    /// accent palette has no green in it — see ``Color/goalDone``.
    private var accent: Color {
        if progress.isAchieved { return .goalDone }
        if progress.isFailed { return .goalMissed }
        return themeAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(uiColor: .secondarySystemGroupedBackground)
                if progress.isAchieved || progress.isFailed {
                    accent.opacity(0.22)
                }
            }
            // Scoped to the background. Animating the whole card instead meant
            // its frame animated too, and while a swipe row was closing the two
            // fought: the card slid out of its own row and resized mid-flight.
            .animation(Motion.animation(.easeOut(duration: 0.35), reduceMotion: reduceMotion),
                       value: progress.isAchieved)
            .animation(Motion.animation(.easeOut(duration: 0.35), reduceMotion: reduceMotion),
                       value: progress.isFailed)
        }
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .sheet(isPresented: $isEnteringManually) {
            ManualEntrySheet(goal: goal) { amount in
                withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
                    onLog(amount)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProgressRing(
                fraction: progress.isFailed ? 1 : progress.fraction,
                symbolName: goal.symbolName,
                accent: accent,
                size: ringSize
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: goal.localizedTitle)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // "Done today" and "Not yet" are different sentences, not
                    // one value changing. Cross-dissolving them draws both at
                    // once and neither is readable.
                    .animation(nil, value: subtitle)
            }

            Spacer(minLength: 8)

            statusIcon
                .animation(Motion.animation(.snappy, reduceMotion: reduceMotion),
                           value: progress.isAchieved)
                .animation(Motion.animation(.snappy, reduceMotion: reduceMotion),
                           value: progress.isFailed)
        }
    }

    /// Every settled state gets a mark. A card with no icon means "still in
    /// progress", so a failed day without one reads as empty and broken.
    @ViewBuilder
    private var statusIcon: some View {
        if progress.isAchieved {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: statusIconSize))
                .foregroundStyle(.white, Color.goalDone)
                .transition(Motion.transition(.scale.combined(with: .opacity),
                                              reduceMotion: reduceMotion))
        } else if progress.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: statusIconSize))
                .foregroundStyle(.white, Color.goalMissed)
                .transition(Motion.transition(.scale.combined(with: .opacity),
                                              reduceMotion: reduceMotion))
        }
    }

    /// The bottom half of the card: buttons while there is work left, the
    /// streak once there is not.
    ///
    /// Both are always laid out, one of them invisible, so the card is exactly
    /// as tall when done as when not. That is not a styling choice — a card
    /// that changes height makes its `List` row animate its own height
    /// underneath SwiftUI, and because `List` does not clip rows the card drew
    /// across its neighbour every time a goal was reset. A constant height
    /// makes that impossible rather than merely unlikely, and it turns the
    /// change into a cross-fade in place with nothing moving.
    private var footer: some View {
        ZStack {
            actions
                .opacity(isSettled ? 0 : 1)
                .allowsHitTesting(!isSettled)
                .accessibilityHidden(isSettled)

            doneFooter
                .opacity(isSettled ? 1 : 0)
                .allowsHitTesting(isSettled)
                .accessibilityHidden(!isSettled)
        }
        .animation(Motion.animation(.easeInOut(duration: 0.3), reduceMotion: reduceMotion),
                   value: isSettled)
    }

    /// Whether the day's work is over, and the card should show its streak
    /// instead of its buttons.
    ///
    /// **Not the same as achieved.** An `atMost` goal is inside its limit from
    /// midnight — `0 <= 2` — so treating "achieved" as "finished" hid every
    /// control on an allowance goal for the whole day. You could not log the
    /// coffee, which also meant the goal could never fail, which is the one
    /// thing it exists to notice. A limit is never finished with; it is only
    /// still intact.
    private var isSettled: Bool {
        goal.direction == .atLeast && progress.isAchieved
    }

    private var doneFooter: some View {
        HStack(spacing: 8) {
            doneSummary
            Spacer(minLength: 8)
            // Hitting the target does not mean you stopped. Reading 25 minutes
            // against a 20-minute goal is true and worth recording, and the
            // long-run totals add up every entry — capping the day at its
            // target would quietly under-report a savings goal.
            //
            // A `.bordered` `.small` button is exactly the height of the
            // action buttons underneath, so the card keeps its one height.
            // Check that before changing this control.
            if goal.loggingStyle == .incremental {
                Button("Add more", systemImage: "plus") { isEnteringManually = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("card.addMore")
            }
        }
    }

    /// What a finished goal says for itself. The streak is the reward for
    /// having done it; without one there is nothing to boast about yet.
    @ViewBuilder
    private var doneSummary: some View {
        if streak > 1 {
            Label {
                Text("\(streak) day streak")
            } icon: {
                Image(systemName: "flame.fill").foregroundStyle(Color.goalMissed)
            }
            .font(.subheadline.weight(.medium))
        } else {
            Text("Done for today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        Group {
            LazyVGrid(columns: columns, spacing: 8) {
                switch goal.loggingStyle {
                case .incremental:
                    ForEach(QuickAddSuggestions.options(for: goal.measure)) { option in
                        // Verbatim: MeasureFormatter has already produced this
                        // in the user's language, so it must not be looked up
                        // as a key.
                        actionButton(
                            Text(verbatim: MeasureFormatter.short(option.amount, measure: goal.measure))
                        ) {
                            withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
                    onLog(option.amount)
                }
                        }
                    }
                    actionButton(Text("Manual")) { isEnteringManually = true }

                case .single:
                    actionButton(Text("Done")) {
                        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
                            onLog(1)
                        }
                    }
                }
            }
        }
    }

    /// Takes a `Text` rather than a `String` on purpose.
    ///
    /// A `String` parameter silently loses localisation: `Text("Manual")` is a
    /// localised key, but `Text(someString)` is not, so passing the literal
    /// through a `String` shipped "Manual" and "Done" in English to every
    /// language while the rest of the screen translated correctly. Asking for
    /// a `Text` forces each caller to say which it means.
    ///
    /// The expanding frame goes on the *label*, not the button. Putting it on
    /// the button only makes the invisible slots equal: the bordered background
    /// still hugs its text, so "5" renders as a tiny pill beside a wide
    /// "Manual".
    private func actionButton(_ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                // 44pt tall because this is the app's primary control and it
                // was about 28 — under the smallest target iOS asks for. The
                // expanding frame goes on the label, not the button: on the
                // button it only equalises the invisible slots, leaving "5"
                // as a tiny pill beside a wide "Manual".
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    /// Built with `String(localized:)` rather than returned as a plain string:
    /// `Text(someString)` does not localise, so a literal here would ship in
    /// English to every language.
    private var subtitle: String {
        if goal.loggingStyle == .single {
            return progress.isAchieved
                ? String(localized: "Done today")
                : String(localized: "Not yet")
        }
        if goal.direction == .atMost {
            return progress.isAchieved
                ? String(localized: "Within limit")
                : String(localized: "Over the limit")
        }
        let done = MeasureFormatter.short(progress.total, measure: goal.measure)
        let target = MeasureFormatter.short(progress.target, measure: goal.measure)
        return String(localized: "\(done) of \(target)")
    }
}

private struct ProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fraction: Double
    let symbolName: String
    let accent: Color
    let size: CGFloat

    /// Keeps the stroke and glyph in proportion as the ring scales, so it reads
    /// the same at every text size instead of turning into a thin hoop.
    private var lineWidth: CGFloat { max(3, size * 0.09) }
    private var glyphSize: CGFloat { size * 0.36 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
        // Decorative. The ring repeats what the subtitle already says in
        // words, and its glyph has no name VoiceOver could read — it was
        // announcing "figure.strengthtraining.functional".
        .accessibilityHidden(true)
        // Must not overshoot. Any bounce sends the trim past its target, and
        // past zero means SwiftUI clamps the negative part and then settles
        // back up through a small positive — a stub of arc on a ring that is
        // supposed to be empty. `easeOut` sweeps without overshooting.
        .animation(Motion.animation(.easeOut(duration: 0.4), reduceMotion: reduceMotion),
                   value: fraction)
        .animation(Motion.animation(.easeOut(duration: 0.3), reduceMotion: reduceMotion),
                   value: accent)
    }
}
