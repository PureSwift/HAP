/// Errors that HAP callbacks can throw.
///
/// `kHAPError_None` from the C ADK maps to a successful return (no throw).
///
/// - Note: Raw values match the C `HAPError` enum (`uint8_t`), offset by 1 (case 0 is `none`, which is not represented).
public enum HAPError: UInt8, Error {
    /// Unknown error.
    case unknown = 1

    /// Operation is not supported in the current state.
    case invalidState = 2

    /// Data has an unexpected format.
    case invalidData = 3

    /// Out of resources.
    case outOfResources = 4

    /// Insufficient authorization.
    case notAuthorized = 5

    /// Operation failed temporarily; retry later.
    case busy = 6
}
