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

    /// Offered first, in this order, because between them they cover almost
    /// every goal this app is likely to hold.
    ///
    /// Alphabetical order put AED, AFN and ALL at the top of a list of about
    /// a hundred and sixty, which is nobody's currency and three scrolls away
    /// from everybody's.
    static let common = ["USD", "EUR", "UAH", "RUB"]

    /// ``common``, plus the reader's own if it is not already one of them.
    ///
    /// Appended rather than put first: a short list whose order never changes
    /// can be learnt, and someone in Poland still finds PLN without scrolling.
    static var featured: [String] {
        let own = deviceDefault
        return common.contains(own) ? common : common + [own]
    }

    /// Everything else, alphabetically.
    static var others: [String] {
        let shown = Set(featured)
        return Locale.commonISOCurrencyCodes.filter { !shown.contains($0) }.sorted()
    }

    /// Every ISO currency, the featured few first.
    ///
    /// Not a curated shortlist: someone saving in a currency we did not think
    /// of would simply be unable to, and the list costs nothing to offer in
    /// full.
    static var all: [String] { featured + others }

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
