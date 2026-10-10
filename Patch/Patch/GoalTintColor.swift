import PatchCore
import SwiftUI

extension GoalTint {
    /// The drawable colour for this tint.
    ///
    /// System colours rather than hand-picked hex values, so every goal adapts
    /// to light and dark, to Increase Contrast, and to the colour filters in
    /// Accessibility settings without a second palette to maintain.
    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        }
    }
}
