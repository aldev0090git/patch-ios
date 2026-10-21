import PatchCore
import SwiftUI

/// First run: says what the app is for, then lets the user pick what to track.
///
/// Two pages rather than one long scroll. The first has one job — set the
/// tone and make the second page make sense — and the second is the only one
/// that asks for anything.
struct OnboardingView: View {
    @Environment(\.themeAccent) private var themeAccent
    @State var model: OnboardingModel
    let onFinish: () -> Void

    @State private var page = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                // Before the picker, not after: choosing from a list of goals
                // means nothing until you know what a goal can do. The
                // allowance shape in particular is the one nobody guesses.
                shapes.tag(1)
                picker.tag(2)
                // Last, so the gestures are the freshest thing in mind when
                // the app opens. A swipe nobody knows about may as well not
                // exist, and Reset lives behind one.
                howItWorks.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(Color.page)
        .task {
            // A beat after the view lands, so the entrance is visible rather
            // than already finished by the time the screen appears.
            withAnimation(.smooth(duration: 0.7)) { appeared = true }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.failure != nil },
                set: { if !$0 { model.failure = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.failure = nil }
        } message: {
            Text(model.failure ?? "")
        }
    }

    // MARK: - Page one

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(themeAccent)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            Text("Patch")
                .font(.largeTitle.bold())

            Text("Small things, kept up. Track what you do each day and watch the days add up.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Page two

    private var shapes: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What a goal can be")
                    .font(.title2.bold())
                Text("Three shapes cover everything. Tap the examples — they really work.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView {
                GoalShapesView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Page three

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What do you want to keep up?")
                    .font(.title2.bold())
                Text("Pick as many as you like. You can change all of this later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.templates) { template in
                        TemplateRow(
                            template: template,
                            isSelected: model.isSelected(template)
                        ) {
                            withAnimation(.snappy) { model.toggle(template) }
                            Haptics.play(.selection)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Page four

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How it works")
                    .font(.title2.bold())
                Text("Three things worth knowing before you start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            HowItWorksView()
                .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            PageDots(count: 4, current: page)

            Button {
                if page < 3 {
                    withAnimation(.snappy) { page += 1 }
                    Haptics.play(.selection)
                } else if model.finish() {
                    // The one time the app has been set up rather than used.
                    Haptics.play(.completed)
                    onFinish()
                }
            } label: {
                primaryLabel
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            // Identified rather than matched by label: the label is localised
            // and changes with the selection count, so a UI test cannot name it.
            .accessibilityIdentifier("onboarding.primary")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Says what will actually happen, including when nothing was ticked —
    /// "Track 0" would be a strange thing to press.
    ///
    /// Three separate `Text`s rather than one holding a chosen `String`.
    /// `Text(flag ? "Get started" : someString)` types the whole expression as
    /// `String`, which is not a localisation key — "Get started" would ship in
    /// English to every language, and never even reach the catalog.
    @ViewBuilder
    private var primaryLabel: some View {
        if page == 0 {
            Text("Get started")
        } else if page < 3 {
            Text("Continue")
        } else if model.selectionCount == 0 {
            Text("Start with none")
        } else {
            Text("Track \(model.selectionCount)")
        }
    }
}

private struct PageDots: View {
    @Environment(\.themeAccent) private var themeAccent
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? themeAccent : Color(uiColor: .tertiaryLabel))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

/// One offered goal. The whole row is the control, not just the tick.
private struct TemplateRow: View {
    @Environment(\.themeAccent) private var themeAccent
    let template: GoalTemplate
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 38

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: template.symbolName)
                    .font(.system(size: iconSize * 0.45))
                    .foregroundStyle(isSelected ? themeAccent : .secondary)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color(uiColor: .tertiarySystemFill), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: template.localizedTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(verbatim: TemplateSummary.text(for: template))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? themeAccent : Color(uiColor: .tertiaryLabel))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Color(uiColor: .secondarySystemGroupedBackground)
                    if isSelected { themeAccent.opacity(0.12) }
                }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
