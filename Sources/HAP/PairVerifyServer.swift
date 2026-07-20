
/// The secure session established by a successful Pair Verify.
public struct PairVerifyResult: Equatable, Hashable, Sendable {

    /// The pairing identifier of the verified controller.
    public let controllerIdentifier: String

    /// The Curve25519 shared secret of the session.
    public let sharedSecret: Data

    /// The `Pair-Verify-Encrypt` session key used during verification.
    public let sessionKey: Data

    public init(controllerIdentifier: String, sharedSecret: Data, sessionKey: Data) {
        self.controllerIdentifier = controllerIdentifier
        self.sharedSecret = sharedSecret
        self.sessionKey = sessionKey
    }

    /// Derives the session security keys for HAP over IP (§6.5.2).
    ///
    /// - Returns: The `AccessoryToControllerKey` (accessory sends / controller reads) and
    ///   `ControllerToAccessoryKey` (controller sends / accessory reads).
    public func controlChannelKeys<Crypto: CryptoProvider>(
        using crypto: Crypto
    ) -> (accessoryToController: Data, controllerToAccessory: Data) {
        let salt = Data(ascii: "Control-Salt")
        let accessoryToController = crypto.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: Data(ascii: "Control-Read-Encryption-Key"),
            outputByteCount: 32
        )
        let controllerToAccessory = crypto.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: Data(ascii: "Control-Write-Encryption-Key"),
            outputByteCount: 32
        )
        return (accessoryToController, controllerToAccessory)
    }
}

// MARK: -

/// Server-side Pair Verify state machine (M1 – M4).
///
/// Sans-I/O: the transport feeds request TLVs to ``handle(_:)`` and sends back the returned
/// response TLVs. On success, ``result`` carries the session's shared secret from which the
/// transport derives its encryption keys.
///
/// - SeeAlso: HAP Specification R2, Section 5.7 Pair Verify
public struct PairVerifyServer<Crypto: CryptoProvider> {

    public enum State: Equatable, Hashable, Sendable {
        /// Waiting for M1 (Verify Start Request).
        case waitingForStartRequest
        /// Waiting for M3 (Verify Finish Request).
        case waitingForFinishRequest
        /// Pair Verify completed; the session is available in ``result``.
        case completed
        /// Pair Verify failed; the session must be discarded.
        case failed
    }

    public private(set) var state: State = .waitingForStartRequest

    /// The established session. Only set once ``state`` is ``State/completed``.
    public private(set) var result: PairVerifyResult?

    private let crypto: Crypto
    private let accessoryIdentifier: String
    private let accessoryLongTermSecretKey: Data
    private let controllerLongTermPublicKey: (String) -> Data?

    private var ephemeralPrivateKey: Data?
    private var ephemeralPublicKey: Data?
    private var controllerEphemeralPublicKey: Data?
    private var sharedSecret: Data?
    private var sessionKey: Data?

    /// Creates a Pair Verify session.
    ///
    /// - Parameters:
    ///   - crypto: The cryptographic provider.
    ///   - accessoryIdentifier: The accessory's pairing identifier (its device ID string).
    ///   - accessoryLongTermSecretKey: The accessory's Ed25519 long-term secret key (32 bytes).
    ///   - controllerLongTermPublicKey: Looks up the Ed25519 long-term public key of a paired
    ///     controller by its pairing identifier, or `nil` if the controller is not paired.
    public init(
        crypto: Crypto,
        accessoryIdentifier: String,
        accessoryLongTermSecretKey: Data,
        controllerLongTermPublicKey: @escaping (String) -> Data?
    ) {
        self.crypto = crypto
        self.accessoryIdentifier = accessoryIdentifier
        self.accessoryLongTermSecretKey = accessoryLongTermSecretKey
        self.controllerLongTermPublicKey = controllerLongTermPublicKey
    }

    /// Processes a request message and returns the response message.
    public mutating func handle(_ request: PairingTLV) -> PairingTLV {
        switch state {
        case .waitingForStartRequest:
            return handleStartRequest(request)
        case .waitingForFinishRequest:
            return handleFinishRequest(request)
        case .completed, .failed:
            return fail(.unknown, responseState: 2)
        }
    }
}

private extension PairVerifyServer {

    /// M1 -> M2: Verify Start.
    mutating func handleStartRequest(_ request: PairingTLV) -> PairingTLV {
        guard request.state == 1,
              let controllerEphemeralPublicKey = request[.publicKey],
              controllerEphemeralPublicKey.count == 32
        else { return fail(.unknown, responseState: 2) }
        let privateKey = crypto.makeCurve25519PrivateKey()
        let publicKey = crypto.curve25519PublicKey(for: privateKey)
        let sharedSecret: Data
        do {
            sharedSecret = try crypto.curve25519SharedSecret(
                privateKey: privateKey,
                peerPublicKey: controllerEphemeralPublicKey
            )
        } catch {
            return fail(.unknown, responseState: 2)
        }
        // AccessoryInfo = AccessoryEphemeralPK ‖ AccessoryPairingID ‖ ControllerEphemeralPK
        var accessoryInfo = publicKey
        accessoryInfo.append(contentsOf: Data(ascii: accessoryIdentifier))
        accessoryInfo.append(contentsOf: controllerEphemeralPublicKey)
        let signature: Data
        do {
            signature = try crypto.ed25519Signature(
                for: accessoryInfo,
                privateKey: accessoryLongTermSecretKey
            )
        } catch {
            return fail(.unknown, responseState: 2)
        }
        var subTLV = PairingTLV()
        subTLV.append(string: accessoryIdentifier, for: .identifier)
        subTLV.append(signature, for: .signature)
        let sessionKey = crypto.hkdfSHA512(
            inputKeyMaterial: sharedSecret,
            salt: Data(ascii: "Pair-Verify-Encrypt-Salt"),
            info: Data(ascii: "Pair-Verify-Encrypt-Info"),
            outputByteCount: 32
        )
        let encryptedData: Data
        do {
            encryptedData = try crypto.seal(
                subTLV.data,
                key: sessionKey,
                nonce: Data(ascii: "PV-Msg02"),
                authenticatedData: Data()
            )
        } catch {
            return fail(.unknown, responseState: 2)
        }
        self.ephemeralPrivateKey = privateKey
        self.ephemeralPublicKey = publicKey
        self.controllerEphemeralPublicKey = controllerEphemeralPublicKey
        self.sharedSecret = sharedSecret
        self.sessionKey = sessionKey
        self.state = .waitingForFinishRequest
        var response = PairingTLV()
        response.append(integer: 2, for: .state)
        response.append(publicKey, for: .publicKey)
        response.append(encryptedData, for: .encryptedData)
        return response
    }

    /// M3 -> M4: Verify Finish.
    mutating func handleFinishRequest(_ request: PairingTLV) -> PairingTLV {
        guard request.state == 3,
              let encryptedData = request[.encryptedData],
              let sessionKey,
              let sharedSecret,
              let ephemeralPublicKey,
              let controllerEphemeralPublicKey
        else { return fail(.unknown, responseState: 4) }
        let decrypted: Data
        do {
            decrypted = try crypto.open(
                encryptedData,
                key: sessionKey,
                nonce: Data(ascii: "PV-Msg03"),
                authenticatedData: Data()
            )
        } catch {
            return fail(.authentication, responseState: 4)
        }
        guard let subTLV = PairingTLV(data: decrypted),
              let controllerIdentifier = subTLV.string(for: .identifier),
              let signature = subTLV[.signature],
              signature.count == 64
        else { return fail(.unknown, responseState: 4) }
        // The controller must be paired.
        guard let controllerPublicKey = controllerLongTermPublicKey(controllerIdentifier) else {
            return fail(.authentication, responseState: 4)
        }
        // ControllerInfo = ControllerEphemeralPK ‖ ControllerPairingID ‖ AccessoryEphemeralPK
        var controllerInfo = controllerEphemeralPublicKey
        controllerInfo.append(contentsOf: Data(ascii: controllerIdentifier))
        controllerInfo.append(contentsOf: ephemeralPublicKey)
        guard crypto.ed25519IsValidSignature(
            signature,
            for: controllerInfo,
            publicKey: controllerPublicKey
        ) else { return fail(.authentication, responseState: 4) }
        self.result = PairVerifyResult(
            controllerIdentifier: controllerIdentifier,
            sharedSecret: sharedSecret,
            sessionKey: sessionKey
        )
        self.state = .completed
        var response = PairingTLV()
        response.append(integer: 4, for: .state)
        return response
    }

    mutating func fail(_ error: PairingError, responseState: UInt8) -> PairingTLV {
        state = .failed
        var response = PairingTLV()
        response.append(integer: UInt64(responseState), for: .state)
        response.append(integer: UInt64(error.rawValue), for: .error)
        return response
    }
}
