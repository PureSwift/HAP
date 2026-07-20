/// The HAP state of a single Bluetooth LE connection.
///
/// Composes the per-connection pipeline: session decryption, PDU reassembly, request
/// routing (pairing characteristics to the pairing state machines, everything else to the
/// procedure server), and response encryption.
///
/// HAP-BLE is a write-then-read protocol: the transport feeds GATT writes to a
/// characteristic into ``handleWrite(characteristicIID:data:now:)`` and serves the
/// subsequent GATT read from ``readResponse()``.
///
/// A thrown error is unrecoverable: the transport must drop the connection.
public struct BLEConnection<
    Crypto: CryptoProvider,
    DataSource: CharacteristicDataSource,
    Configuration: BLEConfigurationContext
> {

    /// The pairing state machines of this connection.
    public private(set) var pairing: BLEPairingSession<Crypto>

    /// The procedure server executing value and configuration procedures.
    public var procedures: BLEProcedureServer<DataSource, Configuration>

    /// Handles a write to the Pairing Pairings characteristic (Add, Remove, and List
    /// Pairings), receiving the request PDU and the verified controller's identifier.
    ///
    /// Set by the accessory server, which owns the pairing store. Invoked only when the
    /// session is secured.
    public var handlePairingManagement: ((BLEPDURequest, _ controller: String) -> BLEPDUResponse)?

    /// The identifier of the controller verified via Pair Verify, once the session
    /// is secured.
    public private(set) var verifiedController: String?

    /// Whether session security is established.
    public var isSecured: Bool {
        secureSession != nil
    }

    private let crypto: Crypto
    private var assembler = BLEPDUAssembler()
    private var secureSession: SecureSession<Crypto>?
    private var pendingResponse: Data?
    private var pendingSecurityUpgrade: PairVerifyResult?

    private let pairSetupIID: UInt16?
    private let pairVerifyIID: UInt16?
    private let pairingPairingsIID: UInt16?

    public init(
        crypto: Crypto,
        pairing: BLEPairingSession<Crypto>,
        procedures: BLEProcedureServer<DataSource, Configuration>
    ) {
        self.crypto = crypto
        self.pairing = pairing
        self.procedures = procedures
        let accessory = procedures.accessory
        self.pairSetupIID = accessory.characteristic(.pairSetup, in: .pairing)
            .map { UInt16(truncatingIfNeeded: $0.characteristic.iid) }
        self.pairVerifyIID = accessory.characteristic(.pairVerify, in: .pairing)
            .map { UInt16(truncatingIfNeeded: $0.characteristic.iid) }
        self.pairingPairingsIID = accessory.characteristic(.pairingPairings, in: .pairing)
            .map { UInt16(truncatingIfNeeded: $0.characteristic.iid) }
    }

    /// Handles a GATT write to a HAP characteristic.
    ///
    /// Decrypts the fragment when the session is secured, reassembles fragmented PDUs, and
    /// once a request is complete, executes it and stages the response for ``readResponse()``.
    ///
    /// - Throws: ``HAPError/notAuthorized`` if session decryption fails, or
    ///   ``HAPError/invalidData`` for malformed PDUs — the connection must then be dropped.
    public mutating func handleWrite(
        characteristicIID: UInt16,
        data: Data,
        now: HAPTime
    ) throws(HAPError) {
        let fragment: Data
        if secureSession != nil {
            fragment = try secureSession!.decrypt(data)
        } else {
            fragment = data
        }
        let pdu: Data?
        do {
            pdu = try assembler.append(fragment)
        } catch {
            throw .invalidData
        }
        guard let pdu else { return }  // more fragments expected
        let response = execute(pdu: pdu, characteristicIID: characteristicIID, now: now)
        var responseData = response.data
        if secureSession != nil {
            responseData = try secureSession!.encrypt(responseData)
        }
        pendingResponse = responseData
    }

    /// Returns the response to the last completed request, or `nil`.
    ///
    /// Consuming the response to a successful Pair Verify M4 enables session security
    /// for all subsequent writes.
    public mutating func readResponse() -> Data? {
        let response = pendingResponse
        pendingResponse = nil
        if let upgrade = pendingSecurityUpgrade {
            secureSession = SecureSession(crypto: crypto, pairVerify: upgrade)
            verifiedController = upgrade.controllerIdentifier
            pendingSecurityUpgrade = nil
        }
        return response
    }

    private mutating func execute(
        pdu: Data,
        characteristicIID: UInt16,
        now: HAPTime
    ) -> BLEPDUResponse {
        let request: BLEPDURequest
        do {
            request = try BLEPDURequest(data: pdu)
        } catch let error as BLEPDUDecodeError {
            if case let .unsupportedOpcode(transactionID) = error {
                return BLEPDUResponse(transactionID: transactionID, status: .unsupportedPDU)
            }
            return BLEPDUResponse(transactionID: 0, status: .invalidRequest)
        } catch {
            return BLEPDUResponse(transactionID: 0, status: .invalidRequest)
        }
        // The PDU must be addressed to the characteristic it was written to.
        guard request.instanceID == characteristicIID else {
            return BLEPDUResponse(transactionID: request.transactionID, status: .invalidInstanceID)
        }
        switch request.instanceID {
        case pairSetupIID:
            return pairing.handlePairSetupWrite(request)
        case pairVerifyIID:
            let response = pairing.handlePairVerifyWrite(request)
            if let result = pairing.pairVerifyResult, secureSession == nil {
                // Security starts after the M4 response has been delivered.
                pendingSecurityUpgrade = result
            }
            return response
        case pairingPairingsIID:
            // Add, Remove, and List Pairings require a secure session.
            guard isSecured, let controller = verifiedController,
                  let handler = handlePairingManagement
            else {
                return BLEPDUResponse(
                    transactionID: request.transactionID,
                    status: .insufficientAuthentication
                )
            }
            return handler(request, controller)
        default:
            return procedures.handle(request, isSecured: isSecured, now: now)
        }
    }
}
