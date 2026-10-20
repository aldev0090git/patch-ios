import Foundation

/// A file the user can take away.
public struct ExportDocument: Hashable, Sendable {
    public let filename: String
    public let data: Data

    public init(filename: String, data: Data) {
        self.filename = filename
        self.data = data
    }

    /// The text of the document, for tests and for anything that wants to
    /// look at it rather than write it out.
    ///
    /// Empty rather than optional when the bytes are not UTF-8: everything
    /// this type produces is written as UTF-8, so a failure here would be a
    /// bug in the writer, not something a caller can do anything about.
    public var text: String { String(bytes: data, encoding: .utf8) ?? "" }
}

/// Everything the user has, in a form they can keep.
///
/// Patch has no account and no server, which is a privacy position worth
/// holding — but it would be a hollow one if the data could never leave the
/// phone. "We don't take your data anywhere" has to come with "and here it is
/// whenever you want it", or it is just a lock with no key.
///
/// Two formats, because they answer different questions:
///
/// - **JSON** is the backup. Every field of every goal and every entry,
///   including archived goals, in a shape that can be read back. Nothing is
///   summarised or rounded away.
/// - **CSV** is for looking at. One row per goal per day with that day's
///   total, which is what opens usefully in Numbers or Excel. It is
///   deliberately *not* a complete record — see ``csv(goals:entries:calendar:)``.
public enum GoalExport {
    /// Bumped when the shape changes, so a future import can tell what it is
    /// reading. Costs one line now and makes the file self-describing for ever.
    ///
    /// - 1: the original.
    /// - 2: entries gained ``Entry/source``, to tell a tap from an amount read
    ///   out of Apple Health. Version 1 files still read back — an entry with
    ///   no recorded source decodes as ``EntrySource/manual``, which is what
    ///   every entry written before the field existed was.
    public static let schemaVersion = 2

    // MARK: - JSON

    /// The complete archive, suitable for reading back in.
    public struct Archive: Codable, Hashable, Sendable {
        public let schemaVersion: Int
        public let exportedAt: Date
        public let goals: [Goal]
        public let entries: [Entry]

        public init(schemaVersion: Int, exportedAt: Date, goals: [Goal], entries: [Entry]) {
            self.schemaVersion = schemaVersion
            self.exportedAt = exportedAt
            self.goals = goals
            self.entries = entries
        }
    }

    public static func json(
        goals: [Goal],
        entries: [Entry],
        exportedAt: Date = .now
    ) -> ExportDocument {
        let archive = Archive(
            schemaVersion: schemaVersion,
            exportedAt: exportedAt,
            // Sorted so two exports of the same data are the same file. A
            // backup that differs every time is one nobody can diff.
            goals: goals.sorted { $0.createdAt < $1.createdAt },
            entries: entries.sorted { $0.loggedAt < $1.loggedAt }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = (try? encoder.encode(archive)) ?? Data()
        return ExportDocument(filename: filename(extension: "json", at: exportedAt), data: data)
    }

    // MARK: - CSV

    /// One row per goal per day it was logged, with that day's total.
    ///
    /// Deliberately a summary rather than the raw entries: four taps of water
    /// in one day is one fact to a person reading a spreadsheet, and four rows
    /// to be summed is not. The JSON export is the complete record; this one is
    /// for looking at.
    ///
    /// Amounts are in canonical units — seconds, millilitres, metres, counts,
    /// major currency units — with a `unit` column saying which. Formatting
    /// them for display would make the file depend on who exported it.
    public static func csv(
        goals: [Goal],
        entries: [Entry],
        calendar: Calendar = .current,
        exportedAt: Date = .now
    ) -> ExportDocument {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let byGoal = Dictionary(grouping: entries, by: \.goalID)
        let progress = ProgressCalculator(calendar: calendar)

        var rows = ["date,goal,amount,unit,target,achieved"]
        for goal in goals.sorted(by: { $0.createdAt < $1.createdAt }) {
            let totals = progress.totalsByDay(for: goal, entries: byGoal[goal.id] ?? [])
            for day in totals.keys.sorted() {
                let total = totals[day] ?? .zero
                let state = progress.progress(for: goal, entries: byGoal[goal.id] ?? [], on: day)
                rows.append([
                    formatter.string(from: day),
                    escape(goal.title),
                    "\(total)",
                    unit(for: goal),
                    "\(goal.dailyTarget(on: day, calendar: calendar))",
                    state.isAchieved ? "yes" : "no"
                ].joined(separator: ","))
            }
        }

        let text = rows.joined(separator: "\n") + "\n"
        return ExportDocument(
            filename: filename(extension: "csv", at: exportedAt),
            data: Data(text.utf8)
        )
    }

    /// The unit column. A money goal says which currency rather than the
    /// useless "major unit" — the whole point of the column is that a reader
    /// can tell what the number means.
    private static func unit(for goal: Goal) -> String {
        guard goal.measure.kind == .currency else { return goal.measure.kind.canonicalUnit }
        return goal.measure.currencyCode ?? goal.measure.kind.canonicalUnit
    }

    /// Quotes a field only when it needs it, and doubles any quote inside.
    ///
    /// A goal called `Read "War and Peace", slowly` would otherwise split into
    /// three columns and take the rest of the file with it.
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func filename(extension suffix: String, at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "patch-\(formatter.string(from: date)).\(suffix)"
    }
}
