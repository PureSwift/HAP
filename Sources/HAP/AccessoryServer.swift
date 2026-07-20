/// The state of a HomeKit accessory server.
///
/// - Note: Raw values match the C `HAPAccessoryServerState` enum (`uint8_t`).
public enum AccessoryServerState: UInt8 {
    /// Server is initialized but not running.
    case idle = 0

    /// Server is running.
    case running = 1

    /// Server is shutting down.
    case stopping = 2
}

// MARK: -

/// Callbacks for accessory server lifecycle events.
///
/// All callbacks must not block.
public struct AccessoryServerCallbacks {
    /// Invoked when the accessory server state changes.
    ///
    /// Retrieve the updated state via `AccessoryServer.state` or `AccessoryServer.isPaired`.
    public var handleUpdatedState: ((AccessoryServer) -> Void)?

    /// Invoked when a HomeKit session is accepted.
    public var handleSessionAccept: ((AccessoryServer, Session) -> Void)?

    /// Invoked when a HomeKit session is invalidated.
    ///
    /// - Warning: The session must not be used after this callback returns.
    public var handleSessionInvalidate: ((AccessoryServer, Session) -> Void)?

    public init() {}
}

// MARK: -

/// A HomeKit accessory server.
///
/// - Note: Corresponds to the opaque C type `HAPAccessoryServerRef` (2418 bytes).
public class AccessoryServer {}
