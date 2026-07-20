import FoundationEmbedded
import TLVCoding

/// A single logical item in a pairing TLV8 payload.
///
/// Fragments of values larger than 255 bytes are coalesced into a single item.
public struct PairingTLVItem: Equatable, Hashable, Sendable {

    /// The type of the item.
    public var type: PairingTLVType

    /// The (defragmented) value of the item.
    public var value: FoundationEmbedded.Data

    public init(type: PairingTLVType, value: FoundationEmbedded.Data) {
        self.type = type
        self.value = value
    }
}

// MARK: -

/// An ordered pairing TLV8 payload.
///
/// Handles the TLV rules of the specification:
/// - Items with unrecognized types are silently ignored when decoding.
/// - Values larger than 255 bytes are fragmented into multiple contiguous items of the
///   same type when encoding, and coalesced when decoding.
/// - Integers are encoded little-endian with the minimum number of bytes.
///
/// - SeeAlso: HAP Specification R2, Section 14.1 TLVs
public struct PairingTLV: Equatable, Hashable, Sendable {

    /// The logical items of the payload, in order.
    public var items: [PairingTLVItem]

    public init(items: [PairingTLVItem] = []) {
        self.items = items
    }
}

// MARK: - Encoding

public extension PairingTLV {

    /// Decodes a TLV8 payload, coalescing fragments and ignoring unrecognized types.
    init?(data: FoundationEmbedded.Data) {
        guard let container = TLVContainer(data: .init(data)) else { return nil }
        var items = [PairingTLVItem]()
        var previousWasFullFragment = false
        for rawItem in container.items {
            guard let type = PairingTLVType(rawValue: rawItem.type.rawValue) else {
                // TLV items with unrecognized types must be silently ignored.
                previousWasFullFragment = false
                continue
            }
            if previousWasFullFragment,
               let lastIndex = items.indices.last,
               items[lastIndex].type == type {
                // Continuation of a fragmented value.
                items[lastIndex].value.append(contentsOf: rawItem.value)
            } else {
                items.append(PairingTLVItem(type: type, value: FoundationEmbedded.Data(rawItem.value)))
            }
            previousWasFullFragment = rawItem.value.count == 255
        }
        self.items = items
    }

    /// Encodes the payload, fragmenting values larger than 255 bytes.
    var data: FoundationEmbedded.Data {
        var container = TLVContainer()
        for item in items {
            if item.value.isEmpty {
                container.items.append(TLVItem(type: item.type.typeCode, value: .init()))
            } else {
                var offset = 0
                while offset < item.value.count {
                    let end = min(offset + 255, item.value.count)
                    container.items.append(
                        TLVItem(type: item.type.typeCode, value: .init(item.value[offset ..< end]))
                    )
                    offset = end
                }
            }
        }
        return FoundationEmbedded.Data(container.data)
    }
}

// MARK: - Item Access

public extension PairingTLV {

    /// The value of the first item with the given type.
    subscript(type: PairingTLVType) -> FoundationEmbedded.Data? {
        items.first(where: { $0.type == type })?.value
    }

    /// Appends an item.
    mutating func append(_ value: FoundationEmbedded.Data, for type: PairingTLVType) {
        items.append(PairingTLVItem(type: type, value: value))
    }

    /// Appends a zero-length separator item, delimiting multiple items of the same type.
    mutating func appendSeparator() {
        append(FoundationEmbedded.Data(), for: .separator)
    }

    /// Appends an integer item (little-endian, minimum number of bytes).
    mutating func append(integer value: UInt64, for type: PairingTLVType) {
        append(Self.encodeInteger(value), for: type)
    }

    /// Appends a UTF-8 string item.
    mutating func append(string value: String, for type: PairingTLVType) {
        append(FoundationEmbedded.Data(Array(value.utf8)), for: type)
    }

    /// Decodes the first item with the given type as an integer.
    func integer(for type: PairingTLVType) -> UInt64? {
        self[type].flatMap(Self.decodeInteger)
    }

    /// Decodes the first item with the given type as a UTF-8 string.
    func string(for type: PairingTLVType) -> String? {
        self[type].map { String(decoding: $0, as: UTF8.self) }
    }
}

// MARK: - Typed Accessors

public extension PairingTLV {

    /// The state of the pairing process (`kTLVType_State`). 1=M1, 2=M2, etc.
    var state: UInt8? {
        integer(for: .state).flatMap { UInt8(exactly: $0) }
    }

    /// The pairing method (`kTLVType_Method`).
    var method: PairingMethod? {
        integer(for: .method)
            .flatMap { UInt8(exactly: $0) }
            .flatMap(PairingMethod.init(rawValue:))
    }

    /// The pairing error (`kTLVType_Error`).
    var error: PairingError? {
        integer(for: .error)
            .flatMap { UInt8(exactly: $0) }
            .flatMap(PairingError.init(rawValue:))
    }

    /// Seconds to delay until retrying a setup code (`kTLVType_RetryDelay`).
    var retryDelay: UInt64? {
        integer(for: .retryDelay)
    }

    /// Pairing type flags (`kTLVType_Flags`).
    var flags: PairingFlags? {
        integer(for: .flags)
            .flatMap { UInt32(exactly: $0) }
            .map(PairingFlags.init(rawValue:))
    }

    /// Permissions of the controller being added (`kTLVType_Permissions`).
    var permissions: PairingPermissions? {
        integer(for: .permissions)
            .flatMap { UInt8(exactly: $0) }
            .map(PairingPermissions.init(rawValue:))
    }
}

// MARK: - Integer Coding

public extension PairingTLV {

    /// Encodes an integer little-endian with the minimum number of bytes.
    static func encodeInteger(_ value: UInt64) -> FoundationEmbedded.Data {
        var bytes: [UInt8] = []
        var remaining = value
        repeat {
            bytes.append(UInt8(truncatingIfNeeded: remaining))
            remaining >>= 8
        } while remaining > 0
        return FoundationEmbedded.Data(bytes)
    }

    /// Decodes a little-endian integer of 1...8 bytes.
    static func decodeInteger(_ data: FoundationEmbedded.Data) -> UInt64? {
        guard !data.isEmpty, data.count <= 8 else { return nil }
        var value: UInt64 = 0
        for (index, byte) in data.enumerated() {
            value |= UInt64(byte) << (8 * index)
        }
        return value
    }
}
