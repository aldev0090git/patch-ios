import Foundation
import Testing
@testable import PatchCore

@Suite("Streaks")
struct StreakTests {
    let calendar = fixedCalendar()
    var streaks: StreakCalculator { StreakCalculator(calendar: calendar) }

    /// Guards the dates the rest of this suite reasons about. If this fails,
    /// every weekday assumption below is wrong and the failures would be baffling.
    @Test("The fixture dates are the weekdays these tests assume")
    func fixtureSanity() {
        #expect(calendar.component(.weekday, from: day(2026, 1, 5)) == Weekday.monday.rawValue)
        #expect(calendar.component(.weekday, from: day(2026, 1, 10)) == Weekday.saturday.rawValue)
        #expect(calendar.component(.weekday, from: day(2026, 1, 11)) == Weekday.sunday.rawValue)
    }

    @Test("A weekday habit keeps its streak across the weekend")
    func weekendDoesNotBreakAWeekdayHabit() {
        let goal = Goal(title: "Gym", measure: .times(1),
                        schedule: .weekdays, createdAt: day(2026, 1, 5))
        // Mon-Fri, then the following Monday. Nothing logged at the weekend.
        let logged = [5, 6, 7, 8, 9, 12].map {
            Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, $0))
        }

        let streak = streaks.currentStreak(for: goal, entries: logged, asOf: day(2026, 1, 12))

        #expect(streak == 6)
    }

    @Test("Today still being unfinished does not wipe out the streak")
    func todayIsForgiving() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let logged = [5, 6, 7].map {
            Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, $0))
        }

        // The 8th is "today" and has nothing logged yet.
        let streak = streaks.currentStreak(for: goal, entries: logged, asOf: day(2026, 1, 8))

        #expect(streak == 3)
    }

    @Test("Finishing today extends the streak to include it")
    func finishingTodayCounts() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 5))
        let logged = [5, 6, 7, 8].map {
            Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, $0))
        }

        let streak = streaks.currentStreak(for: goal, entries: logged, asOf: day(2026, 1, 8))

        #expect(streak == 4)
    }

    @Test("A missed day in the past does break the streak")
    func aMissedDayBreaksTheStreak() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        // The 4th is missing.
        let logged = [1, 2, 3, 5, 6].map {
            Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, $0))
        }

        let streak = streaks.currentStreak(for: goal, entries: logged, asOf: day(2026, 1, 6))

        #expect(streak == 2)
    }

    @Test("A clean-day goal builds a streak from doing nothing")
    func abstinenceAccumulatesWithoutEntries() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 5))

        let streak = streaks.currentStreak(for: goal, entries: [], asOf: day(2026, 1, 10))

        #expect(streak == 6)
    }

    @Test("A slip resets a clean-day streak to the days since")
    func abstinenceResetsAfterASlip() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 1))
        let slip = [Entry(goalID: goal.id, amount: 1, loggedAt: day(2026, 1, 8))]

        let streak = streaks.currentStreak(for: goal, entries: slip, asOf: day(2026, 1, 10))

        #expect(streak == 2) // the 9th and the 10th
    }

    @Test("The streak never reaches back before the goal existed")
    func streakIsBoundedByCreation() {
        let goal = Goal(title: "Don't smoke", measure: .clean,
                        direction: .atMost, createdAt: day(2026, 1, 9))

        let streak = streaks.currentStreak(for: goal, entries: [], asOf: day(2026, 1, 10))

        #expect(streak == 2)
    }

    @Test("The longest streak survives a later gap")
    func longestStreakSurvivesAGap() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        // Four in a row, a gap, then two.
        let logged = [1, 2, 3, 4, 6, 7].map {
            Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, $0))
        }

        let longest = streaks.longestStreak(for: goal, entries: logged, asOf: day(2026, 1, 7))
        let current = streaks.currentStreak(for: goal, entries: logged, asOf: day(2026, 1, 7))

        #expect(longest == 4)
        #expect(current == 2)
    }
}

@Suite("Totals over time")
struct CumulativeTests {
    let calculator = ProgressCalculator(calendar: fixedCalendar())

    @Test("A savings goal totals everything put aside so far")
    func cumulativeTotalSpansDays() {
        let goal = Goal(title: "Save", measure: .money(100, quickAdd: 50),
                        cumulativeTarget: 1000, createdAt: day(2026, 1, 1))
        let deposits = [1, 2, 3].map {
            Entry(goalID: goal.id, amount: 100, loggedAt: day(2026, 1, $0))
        }

        let total = calculator.cumulativeTotal(for: goal, entries: deposits, upTo: day(2026, 1, 3))

        #expect(total == 300)
    }

    @Test("Days after the cutoff are excluded from the total")
    func cumulativeTotalRespectsTheCutoff() {
        let goal = Goal(title: "Save", measure: .money(100, quickAdd: 50), createdAt: day(2026, 1, 1))
        let deposits = [1, 2, 3].map {
            Entry(goalID: goal.id, amount: 100, loggedAt: day(2026, 1, $0))
        }

        let total = calculator.cumulativeTotal(for: goal, entries: deposits, upTo: day(2026, 1, 2))

        #expect(total == 200)
    }

    @Test("A date range produces one progress value per day, oldest first")
    func rangeProducesOneValuePerDay() {
        let goal = Goal(title: "Read", measure: .minutes(20), createdAt: day(2026, 1, 1))
        let logged = [Entry(goalID: goal.id, amount: 1200, loggedAt: day(2026, 1, 2))]

        let week = calculator.progress(for: goal, entries: logged,
                                       from: day(2026, 1, 1), to: day(2026, 1, 7))

        #expect(week.count == 7)
        #expect(week.first?.isAchieved == false)
        #expect(week[1].isAchieved == true)
    }
}
