import Foundation

/// How a goal is logged, which is a property of the goal's shape rather than a
/// presentation choice.
///
/// Reading accumulates through the day and wants a row of amounts. Going to the
/// gym, taking vitamins or confirming a smoke-free day happens once or not at
/// all, so a row of numbers is noise where one button would do.
///
/// Patch records what you *did*, never what you avoided doing. A goal is always
/// something to complete, so every style here is a way of marking progress
/// forward rather than admitting a lapse.
public enum LoggingStyle: Hashable, Sendable {
    /// Accumulate amounts through the day: 10 minutes now, 10 more tonight.
    case incremental
    /// A single yes or no: you went to the gym or you did not.
    case single
}

extension Goal {
    /// How this goal should be logged.
    public var loggingStyle: LoggingStyle {
        if direction == .atLeast && measure.kind == .count && measure.dailyTarget == 1 {
            return .single
        }
        return .incremental
    }
}
