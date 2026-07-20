/// Log levels.
///
/// - Note: Mirrors the C `HAPLogType` enum.
public enum LogLevel: UInt8, Equatable, Hashable, Comparable, Sendable, CaseIterable {

    /// Messages for debugging.
    case debug = 0

    /// Informational messages.
    case info = 1

    /// Default-level messages.
    case `default` = 2

    /// Error messages.
    case error = 3

    /// Fault messages (unrecoverable conditions).
    case fault = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: -

/// Platform logging.
///
/// - Note: Mirrors `HAPPlatformLog.h`.
public protocol PlatformLogger: AnyObject, Sendable {

    /// Logs a message at the given level.
    func log(_ level: LogLevel, message: String)
}
