import TLVCoding

/// Routes HAP-BLE writes on the Pairing service characteristics into the pairing
/// state machines.
///
/// Over Bluetooth LE, pairing requests are performed by writing to the Pair Setup and
/// Pair Verify characteristics using the write-with-response procedure: the pairing TLV
/// travels in the `HAP-Param-Value` parameter of the PDU body, and the response TLV is
/// returned the same way. Pairing runs without session security; once Pair Verify
/// completes, ``pairVerifyResult`` provides the keys for the session's ``SecureSession``.
///
/// - SeeAlso: HAP Specification R2, Sections 5.13 Pairing over Bluetooth LE and
///   7.3.5.5 HAP Characteristic Write-with-Response Procedure
public struct BLEPairingSession<Crypto: CryptoProvider> {

    /// Pairing state shared by the accessory server.
    public struct Configuration {

        /// The accessory's pairing identifier (its device ID string).
        public var accessoryIdentifier: String

        /// The accessory's Ed25519 long-term secret key (32 bytes).
        public var accessoryLongTermSecretKey: Data

        /// The 16-byte SRP salt of the setup code verifier.
        public var setupSalt: Data

        /// The 384-byte SRP verifier of the setup code.
        public var setupVerifier: Data

        /// Looks up the Ed25519 long-term public key of a paired controller.
        public var controllerLongTermPublicKey: (String) -> Data?

        public init(
            accessoryIdentifier: String,
            accessoryLongTermSecretKey: Data,
            setupSalt: Data,
            setupVerifier: Data,
            controllerLongTermPublicKey: @escaping (String) -> Data?
        ) {
            self.accessoryIdentifier = accessoryIdentifier
            self.accessoryLongTermSecretKey = accessoryLongTermSecretKey
            self.setupSalt = setupSalt
            self.setupVerifier = setupVerifier
            self.controllerLongTermPublicKey = controllerLongTermPublicKey
        }
    }

    private let crypto: Crypto
    private let configuration: Configuration

    private var pairSetup: PairSetupServer<Crypto>?
    private var pairVerify: PairVerifyServer<Crypto>?

    /// The pairing established by a completed Pair Setup, to be persisted by the server.
    public private(set) var pairSetupResult: PairSetupResult?

    /// The session established by a completed Pair Verify.
    ///
    /// When set, the transport must enable session security using
    /// ``SecureSession/init(crypto:pairVerify:)``.
    public private(set) var pairVerifyResult: PairVerifyResult?

    public init(crypto: Crypto, configuration: Configuration) {
        self.crypto = crypto
        self.configuration = configuration
    }

    /// Handles a write request PDU addressed to the Pair Setup characteristic.
    public mutating func handlePairSetupWrite(_ request: BLEPDURequest) -> BLEPDUResponse {
        guard let message = Self.pairingMessage(from: request) else {
            return BLEPDUResponse(transactionID: request.transactionID, status: .invalidRequest)
        }
        if pairSetup == nil {
            pairSetup = PairSetupServer(
                crypto: crypto,
                accessoryIdentifier: configuration.accessoryIdentifier,
                accessoryLongTermSecretKey: configuration.accessoryLongTermSecretKey,
                setupSalt: configuration.setupSalt,
                setupVerifier: configuration.setupVerifier
            )
        }
        let response = pairSetup!.handle(message)
        if pairSetup!.state == .completed {
            pairSetupResult = pairSetup!.result
            pairSetup = nil
        } else if pairSetup!.state == .failed {
            pairSetup = nil
        }
        return Self.pairingResponse(response, transactionID: request.transactionID)
    }

    /// Handles a write request PDU addressed to the Pair Verify characteristic.
    ///
    /// A new Pair Verify exchange invalidates any previously established session state.
    public mutating func handlePairVerifyWrite(_ request: BLEPDURequest) -> BLEPDUResponse {
        guard let message = Self.pairingMessage(from: request) else {
            return BLEPDUResponse(transactionID: request.transactionID, status: .invalidRequest)
        }
        if pairVerify == nil {
            pairVerifyResult = nil
            pairVerify = PairVerifyServer(
                crypto: crypto,
                accessoryIdentifier: configuration.accessoryIdentifier,
                accessoryLongTermSecretKey: configuration.accessoryLongTermSecretKey,
                controllerLongTermPublicKey: configuration.controllerLongTermPublicKey
            )
        }
        let response = pairVerify!.handle(message)
        if pairVerify!.state == .completed {
            pairVerifyResult = pairVerify!.result
            pairVerify = nil
        } else if pairVerify!.state == .failed {
            pairVerify = nil
        }
        return Self.pairingResponse(response, transactionID: request.transactionID)
    }

    /// Extracts the pairing TLV from the `HAP-Param-Value` of a write request body.
    ///
    /// Pairing payloads exceed 255 bytes, so the value parameter is fragmented into
    /// multiple TLV items which are coalesced here.
    static func pairingMessage(from request: BLEPDURequest) -> PairingTLV? {
        guard request.opcode == .characteristicWrite,
              let body = request.body,
              let container = TLVContainer(data: .init(body))
        else { return nil }
        var value = [UInt8]()
        var found = false
        for item in container.items where item.type == BLEPDUParamType.value.typeCode {
            found = true
            value.append(contentsOf: item.value)
        }
        guard found else { return nil }
        return PairingTLV(data: Data(value))
    }

    /// Wraps a pairing response TLV in a response PDU body, fragmenting the value
    /// parameter into 255-byte TLV items.
    static func pairingResponse(
        _ message: PairingTLV,
        transactionID: UInt8
    ) -> BLEPDUResponse {
        let value = Array(message.data)
        var body = TLVContainer()
        var offset = 0
        repeat {
            let end = min(offset + 255, value.count)
            body.items.append(TLVItem(
                type: BLEPDUParamType.value.typeCode,
                value: .init(value[offset ..< end])
            ))
            offset = end
        } while offset < value.count
        return BLEPDUResponse(
            transactionID: transactionID,
            status: .success,
            body: Data(body.data)
        )
    }
}
