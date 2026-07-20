import FoundationEmbedded

/// Cryptographically secure random number source.
///
/// Embedded targets should back this with a hardware TRNG; hosted platforms can use the
/// system random number generator. Randomness quality is security-critical: keys, salts,
/// and setup codes are generated from this source.
///
/// - Note: Mirrors `HAPPlatformRandomNumber.h`.
public protocol RandomNumberSource {

    /// Fills the buffer with cryptographically secure random bytes.
    mutating func fill(_ buffer: inout [UInt8])
}

public extension RandomNumberSource {

    /// Returns cryptographically secure random data of the given size.
    mutating func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        fill(&bytes)
        return Data(bytes)
    }
}
