import Foundation

/// A month name standing on its own, capitalised the way its own language
/// capitalises a heading.
///
/// `nonisolated` for the same reason as ``PeriodFormatter``: pure
/// computation, callable from tests off the main actor.
nonisolated enum MonthName {
    /// - Parameter includingYear: adds the year, for a month outside this one.
    static func standalone(
        _ date: Date,
        includingYear: Bool = false,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        // "LLLL", not "MMMM". The two are the same word in English and
        // different words in much of Europe: Russian writes "21 октября"
        // inside a date and "октябрь" on its own, and only "LLLL" asks for
        // the second one.
        formatter.setLocalizedDateFormatFromTemplate(includingYear ? "LLLL y" : "LLLL")
        // And this is what capitalises it. Russian lowercases months in
        // running text but capitalises a heading, which is what this is.
        // `.capitalized` would impose English rules on every language,
        // including the ones that never capitalise a month at all.
        formatter.formattingContext = .standalone
        return formatter.string(from: date)
    }
}
