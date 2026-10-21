import PatchCore
import SwiftUI

/// The row of page themes in Settings.
///
/// Its own file rather than more of ``SettingsView``, which had outgrown the
/// length the linter allows — and this is a self-contained control that
/// happens to live there.
struct ThemePicker: View {
    @Binding var selection: PageTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Wider than the accent swatches, because a gradient needs room to be a
    /// gradient: a circle 30 points across shows one colour and tells you
    /// nothing about where the other end goes.
    var body: some View {
        HStack(spacing: 8) {
            ForEach(PageTheme.allCases) { option in
                Button {
                    selection = option
                    // The home screen follows. Nothing about the day has
                    // changed, so the numbers are reused rather than
                    // recomputed — see `WidgetSnapshot.wearing(_:)`.
                    WidgetPublisher.republish(wearing: option)
                    Haptics.play(.selection)
                } label: {
                    themeSwatch(for: option)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: option.title))
                .accessibilityAddTraits(option == selection ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("theme.\(option.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .animation(Motion.animation(.snappy(duration: 0.25), reduceMotion: reduceMotion),
                   value: selection)
    }

    private func themeSwatch(for option: PageTheme) -> some View {
        let isSelected = option == selection
        return swatchFill(for: option)
            // Narrower since Paper joined: five of these plus their
            // spacing have to fit a grouped row, which is about 318 points.
            .frame(width: 44, height: 34)
            .clipShape(.rect(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .padding(4)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
            }
    }

    @ViewBuilder
    private func swatchFill(for option: PageTheme) -> some View {
        if let gradient = option.gradient(colorScheme) {
            gradient
        } else {
            Color.page
        }
    }
}
