import Foundation
import HealthKit
import PatchCore

/// The only file in Patch that knows HealthKit exists.
///
/// Kept as thin as it can be on purpose. HealthKit is unavailable on the
/// simulator — `isHealthDataAvailable()` is false and there is no Health app
/// to grant anything — so nothing in here can be covered by a test. Every
/// decision therefore lives in ``HealthImportPlanner``, which is pure, and
/// this type does nothing but ask for permission and read numbers.
///
/// **Read permission cannot be queried.** `authorizationStatus(for:)` reports
/// only *write* access; Apple deliberately hides whether a read was refused,
/// because "this app knows you declined" is itself a disclosure. A declined
/// read is indistinguishable from a day with no data — both come back empty.
/// So nothing here ever claims a goal is connected, and the UI says where to
/// go if the numbers do not appear.
/// What ``HealthImporter`` needs from Health, so that it can be tested.
///
/// HealthKit is unavailable on the simulator, so without this seam the
/// importer's own logic — one query per source, a failure in one source not
/// taking the others down — could only ever be checked by hand on a phone.
@MainActor
protocol HealthReading {
    var isAvailable: Bool { get }

    func dailyTotals(
        for source: HealthSource,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [Date: Decimal]
}

@MainActor
final class HealthKitReader: HealthReading {
    /// False on every simulator, and on iPad.
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var isAvailable: Bool { Self.isAvailable }

    /// One per app, as Apple asks. `GoalEditor` is a struct that SwiftUI
    /// rebuilds on every render, so a stored property there would allocate a
    /// new `HKHealthStore` each time the user typed a character.
    static let shared = HealthKitReader()

    private let store = HKHealthStore()

    private init() {}

    /// Prompts for read access, once, for everything Patch might read.
    ///
    /// Asking for all three up front rather than one at a time is a single
    /// sheet instead of three, and iOS only shows rows the user has not
    /// already answered. Throwing is left to the caller: a refusal arrives as
    /// success with no data, so an error here is a real failure.
    func requestAuthorization() async throws {
        guard Self.isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    /// Health's total for each day in the range, in the source's canonical unit.
    ///
    /// Days with no data are absent rather than zero. A zero would be a claim
    /// that the user did nothing, and on a day the phone was left at home that
    /// is not the same thing — the planner skips what it is not told about.
    func dailyTotals(
        for source: HealthSource,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [Date: Decimal] {
        guard Self.isAvailable else { return [:] }

        let anchor = calendar.startOfDay(for: start)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(
                type: Self.quantityType(for: source),
                predicate: HKQuery.predicateForSamples(withStart: anchor, end: end)
            ),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: store)
        let unit = Self.unit(for: source)

        var totals: [Date: Decimal] = [:]
        collection.enumerateStatistics(from: anchor, to: end) { statistics, _ in
            guard let sum = statistics.sumQuantity() else { return }
            let value = sum.doubleValue(for: unit)
            guard value > 0 else { return }
            // Rounded to whole canonical units — whole steps, metres and
            // seconds. Sub-unit precision is noise, and `Decimal(Double)`
            // turns it into long fractions that then show up in an export.
            totals[calendar.startOfDay(for: statistics.startDate)] = Decimal(Int(value.rounded()))
        }
        return totals
    }

    // MARK: - The mapping

    private static var readTypes: Set<HKObjectType> {
        Set(HealthSource.allCases.map(quantityType(for:)))
    }

    private static func quantityType(for source: HealthSource) -> HKQuantityType {
        switch source {
        case .steps: HKQuantityType(.stepCount)
        case .walkingRunningDistance: HKQuantityType(.distanceWalkingRunning)
        case .exerciseMinutes: HKQuantityType(.appleExerciseTime)
        }
    }

    /// Patch's canonical units are already HealthKit's SI units, so this is a
    /// naming exercise rather than a conversion. Keep it that way: a factor
    /// appearing here means a measure kind has drifted from its stored unit.
    private static func unit(for source: HealthSource) -> HKUnit {
        switch source {
        case .steps: .count()
        case .walkingRunningDistance: .meter()
        case .exerciseMinutes: .second()
        }
    }
}
