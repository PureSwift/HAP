
/// An established pairing with a controller.
public struct Pairing: Equatable, Hashable, Sendable {

    /// Maximum length of a pairing identifier in bytes.
    public static let maximumIdentifierLength = 36

    /// The controller's pairing identifier (up to 36 UTF-8 bytes).
    public var identifier: String

    /// The controller's Ed25519 long-term public key (32 bytes).
    public var publicKey: Data

    /// Permissions of the controller.
    public var permissions: PairingPermissions

    /// Whether the controller is an admin.
    public var isAdmin: Bool {
        permissions.contains(.admin)
    }

    public init(identifier: String, publicKey: Data, permissions: PairingPermissions) {
        self.identifier = identifier
        self.publicKey = publicKey
        self.permissions = permissions
    }

    /// Creates the pairing established by a completed Pair Setup.
    public init(_ result: PairSetupResult) {
        self.init(
            identifier: result.controllerIdentifier,
            publicKey: result.controllerLongTermPublicKey,
            permissions: result.permissions
        )
    }
}

// MARK: - Storage Serialization

public extension Pairing {

    /// Size of the serialized storage representation in bytes.
    static let storageSize = maximumIdentifierLength + 1 + 32 + 1

    /// Serializes the pairing in the ADK-compatible key-value store format:
    /// `identifier[36] ‖ numIdentifierBytes ‖ publicKey[32] ‖ permissions`.
    var storageData: Data {
        let identifierBytes = Array(identifier.utf8)
        precondition(identifierBytes.count <= Self.maximumIdentifierLength)
        precondition(publicKey.count == 32)
        var bytes = identifierBytes
        bytes.append(
            contentsOf: [UInt8](repeating: 0, count: Self.maximumIdentifierLength - identifierBytes.count)
        )
        bytes.append(UInt8(identifierBytes.count))
        bytes.append(contentsOf: publicKey)
        bytes.append(permissions.rawValue)
        return Data(bytes)
    }

    /// Decodes a pairing from its storage representation.
    init?(storageData: Data) {
        guard storageData.count == Self.storageSize else { return nil }
        let bytes = Array(storageData)
        let identifierLength = Int(bytes[Self.maximumIdentifierLength])
        guard identifierLength <= Self.maximumIdentifierLength else { return nil }
        self.init(
            identifier: String(decoding: bytes[0 ..< identifierLength], as: UTF8.self),
            publicKey: Data(bytes[(Self.maximumIdentifierLength + 1) ..< (Self.maximumIdentifierLength + 33)]),
            permissions: PairingPermissions(rawValue: bytes[Self.storageSize - 1])
        )
    }
}
