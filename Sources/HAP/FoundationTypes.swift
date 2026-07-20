// Foundation value types used throughout HAP.
//
// Hosted platforms use FoundationEssentials (or Foundation as a fallback) so the public
// API interoperates directly with Foundation types. Embedded Swift builds fall back to
// FoundationEmbedded, which mirrors Foundation's API for bare-metal targets.
//
// These module-level type aliases take precedence over types exported by imported
// modules, so all HAP sources can use `Data` and `UUID` unqualified.

#if canImport(FoundationEssentials) && !hasFeature(Embedded)
import FoundationEssentials

/// The byte buffer type used throughout HAP.
public typealias Data = FoundationEssentials.Data

/// The UUID type used throughout HAP.
public typealias UUID = FoundationEssentials.UUID
#elseif canImport(Foundation) && !hasFeature(Embedded)
import Foundation

/// The byte buffer type used throughout HAP.
public typealias Data = Foundation.Data

/// The UUID type used throughout HAP.
public typealias UUID = Foundation.UUID
#else
import FoundationEmbedded

/// The byte buffer type used throughout HAP.
public typealias Data = FoundationEmbedded.Data

/// The UUID type used throughout HAP.
public typealias UUID = FoundationEmbedded.UUID
#endif
