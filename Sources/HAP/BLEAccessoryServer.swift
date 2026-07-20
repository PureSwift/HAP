/// A HomeKit accessory server for Bluetooth LE.
///
/// Composes the protocol stack for a single accessory: persistent identity and state
/// (``AccessoryServerStorage``), controller pairings (``PairingStore``), and one
/// ``BLEConnection`` per connected controller. The BLE transport binding delivers GATT
/// writes and reads through ``handleWrite(connection:characteristicIID:data:)`` and
/// ``readResponse(connection:)``, and advertises ``advertisementData()`` while no
/// controller is connected.
public final class BLEAccessoryServer<
    Crypto: CryptoProvider,
    Store: KeyValueStore,
    Random: RandomNumberSource,
    DataSource: CharacteristicDataSource
> {

    /// The accessory served, including the standard services.
    public let accessory: Accessory

    /// The controller pairings.
    public let pairings: PairingStore<Store>

    private let crypto: Crypto
    private let clock: any PlatformClock
    private let storage: AccessoryServerStorage<Store, Random>
    private let dataSource: DataSource
    private let setupSalt: Data
    private let setupVerifier: Data
    private let setupHash: SetupHash?

    private var deviceID: Data
    private var deviceIDString: String
    private var longTermSecretKey: Data
    var gsn: BLEAccessoryServerGSN
    var broadcastParameters: BLEBroadcastParameters

    private var connections: [UInt64: BLEConnection<Crypto, DataSource, ConfigurationAdapter>] = [:]

    /// Creates a server, provisioning identity on first launch.
    ///
    /// - Parameters:
    ///   - accessory: The accessory definition. The standard services (Accessory
    ///     Information, HAP Protocol Information, Pairing) must be included and the
    ///     database valid for Bluetooth LE.
    ///   - crypto: The cryptographic provider.
    ///   - store: The persistent key-value store.
    ///   - random: The random number source used for identity provisioning.
    ///   - clock: The platform clock, used to expire timed writes.
    ///   - dataSource: Supplies and accepts characteristic values.
    ///   - setupSalt: The 16-byte SRP salt of the setup code verifier.
    ///   - setupVerifier: The 384-byte SRP verifier of the setup code.
    ///   - setupHash: The setup hash to advertise, when a setup ID is provisioned.
    public init(
        accessory: Accessory,
        crypto: Crypto,
        store: Store,
        random: Random,
        clock: any PlatformClock,
        dataSource: DataSource,
        setupSalt: Data,
        setupVerifier: Data,
        setupHash: SetupHash? = nil
    ) throws(HAPError) {
        self.accessory = accessory
        self.crypto = crypto
        self.clock = clock
        self.dataSource = dataSource
        self.setupSalt = setupSalt
        self.setupVerifier = setupVerifier
        self.setupHash = setupHash
        self.storage = AccessoryServerStorage(store: store, random: random)
        self.pairings = PairingStore(store: store)
        self.deviceID = try storage.deviceID()
        self.deviceIDString = try storage.deviceIDString()
        self.longTermSecretKey = try storage.longTermSecretKey(using: crypto)
        self.gsn = try storage.globalStateNumber()
        self.broadcastParameters = try storage.broadcastParameters()
    }

    // MARK: Connections

    /// Registers a new controller connection.
    ///
    /// The accessory must stop advertising while a controller is connected.
    public func connect(_ connection: UInt64) {
        let pairing = BLEPairingSession(
            crypto: crypto,
            configuration: .init(
                accessoryIdentifier: deviceIDString,
                accessoryLongTermSecretKey: longTermSecretKey,
                setupSalt: setupSalt,
                setupVerifier: setupVerifier,
                controllerLongTermPublicKey: { [pairings] identifier in
                    try? pairings.pairing(for: identifier)?.publicKey
                }
            )
        )
        connections[connection] = BLEConnection(
            crypto: crypto,
            pairing: pairing,
            procedures: BLEProcedureServer(
                accessory: accessory,
                dataSource: dataSource,
                configuration: ConfigurationAdapter(server: self, connection: connection)
            )
        )
    }

    /// Removes a controller connection, ending the GSN increment cycle.
    public func disconnect(_ connection: UInt64) throws(HAPError) {
        connections[connection] = nil
        gsn.endCycle()
        try storage.setGlobalStateNumber(gsn)
    }

    /// Handles a GATT write to a HAP characteristic.
    ///
    /// - Throws: An error requires the transport to drop the connection.
    public func handleWrite(
        connection: UInt64,
        characteristicIID: UInt16,
        data: Data
    ) throws(HAPError) {
        guard connections[connection] != nil else { throw .invalidState }
        do {
            try connections[connection]!.handleWrite(
                characteristicIID: characteristicIID,
                data: data,
                now: clock.now
            )
        } catch {
            connections[connection] = nil
            throw error
        }
        // Persist a pairing established by a completed Pair Setup.
        if let result = connections[connection]!.pairing.pairSetupResult {
            try pairings.add(Pairing(result))
        }
    }

    /// Returns the response to the last completed request on a connection.
    public func readResponse(connection: UInt64) -> Data? {
        connections[connection]?.readResponse()
    }

    /// Whether the connection has established session security.
    public func isSecured(connection: UInt64) -> Bool {
        connections[connection]?.isSecured ?? false
    }

    // MARK: State Changes

    /// Notes a characteristic state change, incrementing the global state number when no
    /// controller is connected (at most once per connect / disconnect cycle).
    public func didChangeState() throws(HAPError) {
        guard connections.isEmpty else { return }
        if gsn.increment() {
            try storage.setGlobalStateNumber(gsn)
        }
    }

    // MARK: Advertising

    /// The regular advertisement payload for the current state.
    ///
    /// - SeeAlso: HAP Specification R2, Section 7.4.2.1
    public func advertisementData() throws(HAPError) -> Data {
        let bytes = Array(deviceID)
        var manufacturerData = BLERegularManufacturerData(
            statusFlags: try pairings.isPaired() ? [] : .notPaired,
            deviceID: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]),
            accessoryCategory: accessory.category,
            globalStateNumber: gsn.gsn,
            configurationNumber: try storage.configurationNumber(),
            setupHash: nil
        )
        if let setupHash {
            let hash = Array(setupHash.data)
            manufacturerData.setupHash = (hash[0], hash[1], hash[2], hash[3])
        }
        return manufacturerData.advertisingData
    }
}

// MARK: - Configuration Adapter

extension BLEAccessoryServer {

    /// Bridges a connection's configuration procedures to the server's shared state.
    final class ConfigurationAdapter: BLEConfigurationContext {

        private unowned let server: BLEAccessoryServer
        private let connection: UInt64
        private var broadcastConfigurations: [UInt64: BLEBroadcastConfiguration] = [:]

        init(server: BLEAccessoryServer, connection: UInt64) {
            self.server = server
            self.connection = connection
        }

        func broadcastConfiguration(
            for characteristic: UInt64
        ) throws(HAPError) -> BLEBroadcastConfiguration {
            broadcastConfigurations[characteristic] ?? BLEBroadcastConfiguration()
        }

        func setBroadcastConfiguration(
            _ configuration: BLEBroadcastConfiguration,
            for characteristic: UInt64
        ) throws(HAPError) {
            broadcastConfigurations[characteristic] = configuration
        }

        var globalStateNumber: UInt16 {
            server.gsn.gsn
        }

        var configurationNumber: UInt8 {
            (try? server.storageConfigurationNumber()) ?? 1
        }

        var advertisingIdentifier: Data {
            server.broadcastParameters.advertisingID ?? server.currentDeviceID()
        }

        func generateBroadcastEncryptionKey() throws(HAPError) -> Data {
            guard let connection = server.connectionState(connection),
                  connection.isSecured,
                  let controller = connection.verifiedController,
                  let sharedSecret = connection.pairing.pairVerifyResult?.sharedSecret,
                  let pairing = try server.pairings.pairing(for: controller)
            else { throw .invalidState }
            server.broadcastParameters.generateKey(
                sharedSecret: sharedSecret,
                controllerPublicKey: pairing.publicKey,
                gsn: server.gsn.gsn,
                using: server.serverCrypto()
            )
            try server.persistBroadcastParameters()
            guard let key = server.broadcastParameters.key else { throw .invalidState }
            return key
        }

        func setAdvertisingIdentifier(_ identifier: Data) throws(HAPError) {
            server.broadcastParameters.advertisingID = identifier
            try server.persistBroadcastParameters()
        }
    }

    func connectionState(_ id: UInt64) -> BLEConnection<Crypto, DataSource, ConfigurationAdapter>? {
        connections[id]
    }

    func currentDeviceID() -> Data {
        deviceID
    }

    func serverCrypto() -> Crypto {
        crypto
    }

    func storageConfigurationNumber() throws(HAPError) -> UInt8 {
        try storage.configurationNumber()
    }

    func persistBroadcastParameters() throws(HAPError) {
        try storage.setBroadcastParameters(broadcastParameters)
    }
}
