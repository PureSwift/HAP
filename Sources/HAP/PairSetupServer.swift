import FoundationEmbedded

/// The controller pairing established by a successful Pair Setup.
public struct PairSetupResult: Equatable, Hashable, Sendable {

    /// The controller's pairing identifier (`iOSDevicePairingID`).
    public let controllerIdentifier: String

    /// The controller's Ed25519 long-term public key (`iOSDeviceLTPK`, 32 bytes).
    public let controllerLongTermPublicKey: Data

    /// Permissions of the paired controller.
    ///
    /// The controller added via Pair Setup is always an admin.
    public var permissions: PairingPermissions { .admin }
}

// MARK: -

/// Server-side Pair Setup state machine (M1 – M6).
///
/// Sans-I/O: the transport feeds request TLVs to ``handle(_:)`` and sends back the returned
/// response TLVs. Errors are reported to the controller as TLV error items per the
/// specification; after an error the session is ``State/failed`` and must be discarded.
///
/// - SeeAlso: HAP Specification R2, Section 5.6 Pair Setup
public struct PairSetupServer<Crypto: CryptoProvider> {

    public enum State: Equatable, Hashable, Sendable {
        /// Waiting for M1 (SRP Start Request).
        case waitingForStartRequest
        /// Waiting for M3 (SRP Verify Request).
        case waitingForVerifyRequest
        /// Waiting for M5 (Exchange Request).
        case waitingForExchangeRequest
        /// Pair Setup completed; the pairing is available in ``result``.
        case completed
        /// Pair Setup failed; the session must be discarded.
        case failed
    }

    public private(set) var state: State = .waitingForStartRequest

    /// The established pairing. Only set once ``state`` is ``State/completed``.
    public private(set) var result: PairSetupResult?

    private let crypto: Crypto
    private let accessoryIdentifier: String
    private let accessoryLongTermSecretKey: Data
    private let setupSalt: Data
    private let setupVerifier: Data
    private var srp: Crypto.SRP?

    /// Creates a Pair Setup session.
    ///
    /// - Parameters:
    ///   - crypto: The cryptographic provider.
    ///   - accessoryIdentifier: The accessory's pairing identifier (its device ID string).
    ///   - accessoryLongTermSecretKey: The accessory's Ed25519 long-term secret key (32 bytes).
    ///   - setupSalt: The 16-byte SRP salt of the setup code verifier.
    ///   - setupVerifier: The 384-byte SRP verifier of the setup code.
    public init(
        crypto: Crypto,
        accessoryIdentifier: String,
        accessoryLongTermSecretKey: Data,
        setupSalt: Data,
        setupVerifier: Data
    ) {
        self.crypto = crypto
        self.accessoryIdentifier = accessoryIdentifier
        self.accessoryLongTermSecretKey = accessoryLongTermSecretKey
        self.setupSalt = setupSalt
        self.setupVerifier = setupVerifier
    }

    /// Processes a request message and returns the response message.
    public mutating func handle(_ request: PairingTLV) -> PairingTLV {
        switch state {
        case .waitingForStartRequest:
            return handleStartRequest(request)
        case .waitingForVerifyRequest:
            return handleVerifyRequest(request)
        case .waitingForExchangeRequest:
            return handleExchangeRequest(request)
        case .completed, .failed:
            return fail(.unknown, responseState: 2)
        }
    }
}

private extension PairSetupServer {

    static var username: String { "Pair-Setup" }

    /// M1 -> M2: SRP Start.
    mutating func handleStartRequest(_ request: PairingTLV) -> PairingTLV {
        guard request.state == 1,
              let method = request.method,
              method == .pairSetup || method == .pairSetupWithAuth
        else { return fail(.unknown, responseState: 2) }
        let srp: Crypto.SRP
        do {
            srp = try crypto.makeSRPServer(
                username: Self.username,
                salt: setupSalt,
                verifier: setupVerifier
            )
        } catch {
            return fail(.unknown, responseState: 2)
        }
        self.srp = srp
        self.state = .waitingForVerifyRequest
        var response = PairingTLV()
        response.append(integer: 2, for: .state)
        response.append(srp.publicKey, for: .publicKey)
        response.append(setupSalt, for: .salt)
        return response
    }

    /// M3 -> M4: SRP Verify.
    mutating func handleVerifyRequest(_ request: PairingTLV) -> PairingTLV {
        guard request.state == 3,
              let clientPublicKey = request[.publicKey],
              let clientProof = request[.proof],
              srp != nil
        else { return fail(.unknown, responseState: 4) }
        let serverProof: Data
        do {
            try srp!.processClientPublicKey(clientPublicKey)
            serverProof = try srp!.verifyClientProof(clientProof)
        } catch {
            // Setup code mismatch or illegal client public key.
            return fail(.authentication, responseState: 4)
        }
        self.state = .waitingForExchangeRequest
        var response = PairingTLV()
        response.append(integer: 4, for: .state)
        response.append(serverProof, for: .proof)
        return response
    }

    /// M5 -> M6: Exchange.
    mutating func handleExchangeRequest(_ request: PairingTLV) -> PairingTLV {
        guard request.state == 5,
              let encryptedData = request[.encryptedData],
              let srp
        else { return fail(.unknown, responseState: 6) }
        let sessionKey = crypto.hkdfSHA512(
            inputKeyMaterial: srp.sessionKey,
            salt: Data(ascii: "Pair-Setup-Encrypt-Salt"),
            info: Data(ascii: "Pair-Setup-Encrypt-Info"),
            outputByteCount: 32
        )
        // Decrypt and verify the controller's identity (M5 verification, §5.6.6.1).
        let decrypted: Data
        do {
            decrypted = try crypto.open(
                encryptedData,
                key: sessionKey,
                nonce: Data(ascii: "PS-Msg05"),
                authenticatedData: Data()
            )
        } catch {
            return fail(.authentication, responseState: 6)
        }
        guard let subTLV = PairingTLV(data: decrypted),
              let controllerIdentifier = subTLV.string(for: .identifier),
              let controllerPublicKey = subTLV[.publicKey],
              let signature = subTLV[.signature],
              controllerPublicKey.count == 32,
              signature.count == 64
        else { return fail(.unknown, responseState: 6) }
        let controllerX = crypto.hkdfSHA512(
            inputKeyMaterial: srp.sessionKey,
            salt: Data(ascii: "Pair-Setup-Controller-Sign-Salt"),
            info: Data(ascii: "Pair-Setup-Controller-Sign-Info"),
            outputByteCount: 32
        )
        var controllerInfo = controllerX
        controllerInfo.append(contentsOf: Data(ascii: controllerIdentifier))
        controllerInfo.append(contentsOf: controllerPublicKey)
        guard crypto.ed25519IsValidSignature(
            signature,
            for: controllerInfo,
            publicKey: controllerPublicKey
        ) else { return fail(.authentication, responseState: 6) }

        // Generate the accessory's identity response (M6 response generation, §5.6.6.2).
        let accessoryX = crypto.hkdfSHA512(
            inputKeyMaterial: srp.sessionKey,
            salt: Data(ascii: "Pair-Setup-Accessory-Sign-Salt"),
            info: Data(ascii: "Pair-Setup-Accessory-Sign-Info"),
            outputByteCount: 32
        )
        let accessoryPublicKey = crypto.ed25519PublicKey(for: accessoryLongTermSecretKey)
        var accessoryInfo = accessoryX
        accessoryInfo.append(contentsOf: Data(ascii: accessoryIdentifier))
        accessoryInfo.append(contentsOf: accessoryPublicKey)
        let accessorySignature: Data
        do {
            accessorySignature = try crypto.ed25519Signature(
                for: accessoryInfo,
                privateKey: accessoryLongTermSecretKey
            )
        } catch {
            return fail(.unknown, responseState: 6)
        }
        var responseSubTLV = PairingTLV()
        responseSubTLV.append(string: accessoryIdentifier, for: .identifier)
        responseSubTLV.append(accessoryPublicKey, for: .publicKey)
        responseSubTLV.append(accessorySignature, for: .signature)
        let responseEncrypted: Data
        do {
            responseEncrypted = try crypto.seal(
                responseSubTLV.data,
                key: sessionKey,
                nonce: Data(ascii: "PS-Msg06"),
                authenticatedData: Data()
            )
        } catch {
            return fail(.unknown, responseState: 6)
        }
        self.result = PairSetupResult(
            controllerIdentifier: controllerIdentifier,
            controllerLongTermPublicKey: controllerPublicKey
        )
        self.state = .completed
        var response = PairingTLV()
        response.append(integer: 6, for: .state)
        response.append(responseEncrypted, for: .encryptedData)
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

// MARK: -

internal extension Data {

    /// Creates data from the UTF-8 bytes of a string.
    init(ascii string: String) {
        self.init(Array(string.utf8))
    }
}
