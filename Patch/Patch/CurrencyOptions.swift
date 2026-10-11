import Foundation

/// The currencies a money goal can be kept in.
///
/// `nonisolated` for the same reason as the formatters: pure computation, and
/// the tests must be able to call it off the main actor.
nonisolated enum CurrencyOptions {
    /// What the reader's own region uses, which is the right answer almost
    /// every time and means the picker is usually never opened.
    static var deviceDefault: String {
        Locale.autoupdatingCurrent.currency?.identifier ?? "USD"
    }

    /// Every ISO currency, with the reader's own first.
    ///
    /// Not a curated shortlist: someone saving in a currency we did not think
    /// of would simply be unable to, and the list costs nothing to offer in
    /// full.
    static var all: [String] {
        let own = deviceDefault
        let rest = Locale.commonISOCurrencyCodes.filter { $0 != own }.sorted()
        return [own] + rest
    }

    /// "EUR — Euro", in the reader's language.
    static func label(for code: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard let name = locale.localizedString(forCurrencyCode: code) else { return code }
        return "\(code) — \(name)"
    }

    /// "€", "₴", "$". Falls back to the code when a symbol would be ambiguous
    /// or missing — a visible "SEK" beats an invisible nothing.
    static func symbol(for code: String, locale: Locale = .autoupdatingCurrent) -> String {
        let formatted = Decimal.zero.formatted(
            .currency(code: code).precision(.fractionLength(0)).locale(locale)
        )
        let symbol = formatted
            .components(separatedBy: CharacterSet(charactersIn: "0123456789"))
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return symbol.isEmpty ? code : symbol
    }
}
