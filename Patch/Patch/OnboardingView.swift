import PatchCore
import SwiftUI

/// First run: says what the app is for, then lets the user pick what to track.
///
/// Two pages rather than one long scroll. The first has one job — set the
/// tone and make the second page make sense — and the second is the only one
/// that asks for anything.
struct OnboardingView: View {
    @State var model: OnboardingModel
    let onFinish: () -> Void

    @State private var page = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                picker.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
                .foregroundStyle(Color.accentColor)
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
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            PageDots(count: 2, current: page)

            Button {
                if page == 0 {
                    withAnimation(.snappy) { page = 1 }
                } else if model.finish() {
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
        } else if model.selectionCount == 0 {
            Text("Start with none")
        } else {
            Text("Track \(model.selectionCount)")
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color(uiColor: .tertiaryLabel))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

/// One offered goal. The whole row is the control, not just the tick.
private struct TemplateRow: View {
    let template: GoalTemplate
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 38

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: template.symbolName)
                    .font(.system(size: iconSize * 0.45))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
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
                    .foregroundStyle(isSelected ? Color.accentColor : Color(uiColor: .tertiaryLabel))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Color(uiColor: .secondarySystemGroupedBackground)
                    if isSelected { Color.accentColor.opacity(0.12) }
                }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
