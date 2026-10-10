import Foundation

/// A goal's colour, named rather than specified.
///
/// The domain says *which* colour a goal is, never what that colour's value is:
/// resolving a name to something drawable is the app's job, and it has to
/// differ between light and dark anyway. Storing a name also survives a
/// redesign — changing the palette never touches saved data.
///
/// No shipped template uses ``red``. A goal's colour tints its own buttons, and
/// red is how this app signals a destructive action — a red "Done" button looks
/// like it will undo something.
public enum GoalTint: String, Codable, Sendable, CaseIterable, Hashable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal
}
