/// A point in time, in milliseconds relative to an implementation-defined reference
/// (e.g. system boot).
///
/// - Note: Corresponds to the C `HAPTime` type (`uint64_t`, milliseconds).
public struct HAPTime: RawRepresentable, Equatable, Hashable, Comparable, Sendable {

    /// Milliseconds since the reference time.
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Milliseconds since the reference time.
    public var milliseconds: UInt64 {
        rawValue
    }

    /// Returns a time offset into the future by the given number of milliseconds.
    public func advanced(byMilliseconds milliseconds: UInt64) -> HAPTime {
        HAPTime(rawValue: rawValue + milliseconds)
    }

    public static func < (lhs: HAPTime, rhs: HAPTime) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: -

/// Platform clock.
///
/// - Note: Mirrors `HAPPlatformClock.h`.
public protocol PlatformClock: AnyObject, Sendable {

    /// The current time.
    ///
    /// Must be monotonic: the time must never jump backwards, including across sleep.
    var now: HAPTime { get }
}
