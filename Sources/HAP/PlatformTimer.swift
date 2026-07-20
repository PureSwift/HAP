/// Identifier of a scheduled timer.
///
/// - Note: Corresponds to the C `HAPPlatformTimerRef` type.
public struct TimerID: RawRepresentable, Equatable, Hashable, Sendable {

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

// MARK: -

/// Platform timer scheduling.
///
/// Completions are invoked on the platform run loop — the same execution context that
/// delivers all other platform events to the accessory server.
///
/// - Note: Mirrors `HAPPlatformTimer.h`.
public protocol PlatformTimer: AnyObject {

    /// Schedules a one-shot timer that fires at the given deadline.
    ///
    /// If the deadline is in the past, the timer fires as soon as possible.
    ///
    /// - Throws: ``HAPError/outOfResources`` if no more timers can be allocated.
    func schedule(
        deadline: HAPTime,
        _ completion: @escaping @Sendable (TimerID) -> Void
    ) throws(HAPError) -> TimerID

    /// Cancels a scheduled timer.
    ///
    /// The completion of a cancelled timer is not invoked.
    func cancel(_ timer: TimerID)
}
