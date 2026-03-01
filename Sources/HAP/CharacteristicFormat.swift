//
//  CharacteristicFormat.swift
//  HAP
//
//  Created by Alsey Coleman Miller on 2/28/26.
//

/// Formats that HomeKit characteristics can have.
///
/// The format must always match the type of the characteristic structure.
/// For Apple-defined characteristics, the format must be used exactly as defined in the specification.
/// For vendor-specific characteristics, any format may be chosen.
public enum CharacteristicFormat: UInt8, Equatable, Hashable, Sendable, CaseIterable {
    
    /// Opaque data blob. Raw bytes.
    ///
    /// Default format in case no other format has been specified.
    case data = 0

    /// Boolean. True or false.
    case bool = 1

    /// Unsigned 8-bit integer.
    case uint8 = 2

    /// Unsigned 16-bit integer.
    case uint16 = 3

    /// Unsigned 32-bit integer.
    case uint32 = 4

    /// Unsigned 64-bit integer.
    case uint64 = 5

    /// Signed 32-bit integer.
    case int = 6

    /// 32-bit floating point.
    case float = 7

    /// UTF-8 string.
    case string = 8

    /// One or more TLV8s.
    case tlv8 = 9
}
