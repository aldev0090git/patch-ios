import Foundation

/// How a goal is logged, which is a property of the goal's shape rather than a
/// presentation choice.
///
/// Reading accumulates through the day and wants a row of amounts. Going to the
/// gym happens once or not at all, so a row of numbers is noise where one
/// button would do. Not smoking is a clean day until proven otherwise, so the
/// only thing there is ever to record is a slip.
public enum LoggingStyle: Hashable, Sendable {
    /// Accumulate amounts through the day: 10 minutes now, 10 more tonight.
    case incremental
    /// A single yes or no: you went to the gym or you did not.
    case single
    /// Clean by default. The only thing worth logging is a lapse.
    case abstinence
}

extension Goal {
    /// How this goal should be logged.
    public var loggingStyle: LoggingStyle {
        if direction == .atMost && measure.dailyTarget == .zero {
            return .abstinence
        }
        if direction == .atLeast && measure.kind == .count && measure.dailyTarget == 1 {
            return .single
        }
        return .incremental
    }
}
