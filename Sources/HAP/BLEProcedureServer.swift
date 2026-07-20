import TLVCoding

/// Executes HAP-BLE procedures against an accessory's attribute database.
///
/// Sans-I/O: the transport decodes a ``BLEPDURequest`` from the GATT characteristic write,
/// passes it to ``handle(_:isSecured:now:)``, and writes the returned ``BLEPDUResponse``
/// back to the controller.
///
/// - SeeAlso: HAP Specification R2, Section 7.3.5 HAP Procedures
public struct BLEProcedureServer<
    DataSource: CharacteristicDataSource,
    Configuration: BLEConfigurationContext
> {

    /// The accessory whose attribute database is served.
    public var accessory: Accessory

    /// Supplies and accepts characteristic values.
    public var dataSource: DataSource

    /// Supplies broadcast configuration and accessory-wide protocol state.
    public var configuration: Configuration

    /// A write staged by a timed write procedure, pending execution.
    private var pendingWrite: PendingWrite?

    private struct PendingWrite {
        var instanceID: UInt64
        var value: CharacteristicValue
        var expiry: HAPTime
        var authorizationData: Data?
        var remote: Bool
    }

    public init(accessory: Accessory, dataSource: DataSource, configuration: Configuration) {
        self.accessory = accessory
        self.dataSource = dataSource
        self.configuration = configuration
    }

    /// Executes the procedure of a request PDU.
    ///
    /// - Parameters:
    ///   - request: The decoded request PDU.
    ///   - isSecured: Whether the request arrived over a secure session established via
    ///     Pair Verify. Procedures other than signature reads require either a secure
    ///     session or a characteristic that permits open access.
    ///   - now: The current time, used to expire staged timed writes.
    public mutating func handle(
        _ request: BLEPDURequest,
        isSecured: Bool,
        now: HAPTime
    ) -> BLEPDUResponse {
        switch request.opcode {
        case .characteristicSignatureRead:
            return characteristicSignatureRead(request)
        case .serviceSignatureRead:
            return serviceSignatureRead(request)
        case .characteristicRead:
            return characteristicRead(request, isSecured: isSecured)
        case .characteristicWrite:
            return characteristicWrite(request, isSecured: isSecured)
        case .characteristicTimedWrite:
            return characteristicTimedWrite(request, isSecured: isSecured, now: now)
        case .characteristicExecuteWrite:
            return characteristicExecuteWrite(request, isSecured: isSecured, now: now)
        case .characteristicConfiguration:
            return characteristicConfiguration(request, isSecured: isSecured)
        case .protocolConfiguration:
            return protocolConfiguration(request, isSecured: isSecured)
        }
    }
}

// MARK: - Procedures

private extension BLEProcedureServer {

    /// HAP Characteristic Signature Read Procedure (§7.3.5.1).
    ///
    /// Supported with and without a secure session.
    func characteristicSignatureRead(_ request: BLEPDURequest) -> BLEPDUResponse {
        guard let match = accessory.characteristic(iid: UInt64(request.instanceID)) else {
            return response(request, .invalidInstanceID)
        }
        return response(
            request,
            .success,
            body: match.characteristic.bleSignatureReadResponseBody(service: match.service)
        )
    }

    /// HAP Service Signature Read Procedure (§7.3.4.13).
    ///
    /// An invalid service instance ID yields a valid response with zeroed properties.
    func serviceSignatureRead(_ request: BLEPDURequest) -> BLEPDUResponse {
        guard let service = accessory.service(iid: UInt64(request.instanceID)) else {
            return response(request, .success, body: Service.bleEmptySignatureReadResponseBody)
        }
        return response(request, .success, body: service.bleSignatureReadResponseBody)
    }

    /// HAP Characteristic Read Procedure (§7.3.5.3).
    func characteristicRead(
        _ request: BLEPDURequest,
        isSecured: Bool
    ) -> BLEPDUResponse {
        guard let match = accessory.characteristic(iid: UInt64(request.instanceID)) else {
            return response(request, .invalidInstanceID)
        }
        let characteristic = match.characteristic
        guard isSecured || characteristic.properties.contains(.bleReadableWithoutSecurity) else {
            return response(request, .insufficientAuthentication)
        }
        guard characteristic.properties.contains(.readable) else {
            return response(request, .invalidRequest)
        }
        let value: CharacteristicValue
        do {
            value = try dataSource.readValue(CharacteristicReadContext(
                transportType: .ble,
                characteristic: characteristic,
                service: match.service,
                accessory: accessory
            ))
        } catch {
            return response(request, Self.status(for: error))
        }
        guard value.format == characteristic.format else {
            return response(request, .invalidRequest)
        }
        var body = TLVContainer()
        body.items.append(TLVItem(
            type: BLEPDUParamType.value.typeCode,
            value: .init(value.bleData)
        ))
        return response(request, .success, body: Data(body.data))
    }

    /// HAP Characteristic Write Procedure (§7.3.5.2).
    mutating func characteristicWrite(
        _ request: BLEPDURequest,
        isSecured: Bool
    ) -> BLEPDUResponse {
        guard let match = accessory.characteristic(iid: UInt64(request.instanceID)) else {
            return response(request, .invalidInstanceID)
        }
        let characteristic = match.characteristic
        guard isSecured || characteristic.properties.contains(.bleWritableWithoutSecurity) else {
            return response(request, .insufficientAuthentication)
        }
        // A characteristic that requires a timed write must not accept a plain write.
        guard !characteristic.properties.contains(.requiresTimedWrite) else {
            return response(request, .invalidRequest)
        }
        guard let parameters = WriteParameters(body: request.body, format: characteristic.format),
              let value = parameters.value
        else { return response(request, .invalidRequest) }
        return applyWrite(
            request,
            value: value,
            match: match,
            authorizationData: parameters.authorizationData,
            remote: parameters.remote
        )
    }

    /// HAP Characteristic Timed Write Procedure (§7.3.5.4).
    ///
    /// Stages the value; it is applied by a subsequent execute write procedure that arrives
    /// before the time-to-live elapses.
    mutating func characteristicTimedWrite(
        _ request: BLEPDURequest,
        isSecured: Bool,
        now: HAPTime
    ) -> BLEPDUResponse {
        guard let match = accessory.characteristic(iid: UInt64(request.instanceID)) else {
            return response(request, .invalidInstanceID)
        }
        let characteristic = match.characteristic
        guard isSecured || characteristic.properties.contains(.bleWritableWithoutSecurity) else {
            return response(request, .insufficientAuthentication)
        }
        guard let parameters = WriteParameters(body: request.body, format: characteristic.format),
              let value = parameters.value,
              let ttl = parameters.timeToLive
        else { return response(request, .invalidRequest) }
        pendingWrite = PendingWrite(
            instanceID: UInt64(request.instanceID),
            value: value,
            // The time-to-live is expressed in units of 100 ms.
            expiry: now.advanced(byMilliseconds: UInt64(ttl) * 100),
            authorizationData: parameters.authorizationData,
            remote: parameters.remote
        )
        return response(request, .success)
    }

    /// HAP Characteristic Execute Write Procedure (§7.3.5.4).
    mutating func characteristicExecuteWrite(
        _ request: BLEPDURequest,
        isSecured: Bool,
        now: HAPTime
    ) -> BLEPDUResponse {
        guard let pending = pendingWrite else {
            return response(request, .invalidRequest)
        }
        pendingWrite = nil
        guard pending.instanceID == UInt64(request.instanceID),
              now <= pending.expiry
        else { return response(request, .invalidRequest) }
        guard let match = accessory.characteristic(iid: pending.instanceID) else {
            return response(request, .invalidInstanceID)
        }
        guard isSecured || match.characteristic.properties.contains(.bleWritableWithoutSecurity)
        else { return response(request, .insufficientAuthentication) }
        return applyWrite(
            request,
            value: pending.value,
            match: match,
            authorizationData: pending.authorizationData,
            remote: pending.remote
        )
    }

    /// Validates and applies a value, shared by the write and execute write procedures.
    mutating func applyWrite(
        _ request: BLEPDURequest,
        value: CharacteristicValue,
        match: (characteristic: Characteristic, service: Service),
        authorizationData: Data?,
        remote: Bool
    ) -> BLEPDUResponse {
        let characteristic = match.characteristic
        guard characteristic.properties.contains(.writable) else {
            return response(request, .invalidRequest)
        }
        guard characteristic.isValidValue(value) else {
            return response(request, .invalidRequest)
        }
        do {
            try dataSource.writeValue(value, CharacteristicWriteContext(
                transportType: .ble,
                characteristic: characteristic,
                service: match.service,
                accessory: accessory,
                remote: remote,
                authorizationData: authorizationData
            ))
        } catch {
            return response(request, Self.status(for: error))
        }
        return response(request, .success)
    }
}



// MARK: - Configuration Procedures

private extension BLEProcedureServer {

    /// HAP Characteristic Configuration Procedure (§7.3.5.8).
    mutating func characteristicConfiguration(
        _ request: BLEPDURequest,
        isSecured: Bool
    ) -> BLEPDUResponse {
        guard isSecured else {
            return response(request, .insufficientAuthentication)
        }
        guard let match = accessory.characteristic(iid: UInt64(request.instanceID)) else {
            return response(request, .invalidInstanceID)
        }
        guard let parameters = ConfigurationParameters(body: request.body) else {
            return response(request, .invalidRequest)
        }
        do {
            var broadcast = try configuration.broadcastConfiguration(
                for: UInt64(request.instanceID)
            )
            if let properties = parameters.properties {
                let enable = BLECharacteristicConfigurationProperties(rawValue: properties)
                    .contains(.broadcastNotification)
                // Only characteristics that support broadcast notifications can enable them.
                guard !enable
                        || match.characteristic.properties.contains(.bleSupportsBroadcastNotification)
                else { return response(request, .invalidRequest) }
                broadcast.isEnabled = enable
            }
            if let interval = parameters.broadcastInterval {
                broadcast.interval = interval
            }
            try configuration.setBroadcastConfiguration(broadcast, for: UInt64(request.instanceID))
            // The accessory must include all parameters in the response, even defaults.
            var body = TLVContainer()
            body.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x01),  // properties
                value: .init(littleEndianBytes(
                    broadcast.isEnabled
                        ? BLECharacteristicConfigurationProperties.broadcastNotification.rawValue
                        : 0
                ))
            ))
            body.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x02),  // broadcast interval
                value: .init([broadcast.interval.rawValue])
            ))
            return response(request, .success, body: Data(body.data))
        } catch {
            return response(request, Self.status(for: error))
        }
    }

    /// HAP Protocol Configuration Procedure (§7.3.5.9).
    ///
    /// Directed at the HAP Protocol Information service.
    mutating func protocolConfiguration(
        _ request: BLEPDURequest,
        isSecured: Bool
    ) -> BLEPDUResponse {
        guard isSecured else {
            return response(request, .insufficientAuthentication)
        }
        guard let service = accessory.service(iid: UInt64(request.instanceID)),
              service.properties.contains(.bleSupportsConfiguration)
        else { return response(request, .invalidInstanceID) }
        guard let parameters = ProtocolConfigurationParameters(body: request.body) else {
            return response(request, .invalidRequest)
        }
        do {
            var broadcastKey: Data?
            if let advertisingIdentifier = parameters.advertisingIdentifier {
                try configuration.setAdvertisingIdentifier(advertisingIdentifier)
            }
            if parameters.generateBroadcastEncryptionKey {
                broadcastKey = try configuration.generateBroadcastEncryptionKey()
            }
            guard parameters.getAllParams
                    || parameters.generateBroadcastEncryptionKey
                    || parameters.advertisingIdentifier != nil
            else { return response(request, .invalidRequest) }
            // Response parameters (Table 7-34).
            var body = TLVContainer()
            body.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x01),  // current state number
                value: .init(littleEndianBytes(configuration.globalStateNumber))
            ))
            body.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x02),  // current config number
                value: .init([configuration.configurationNumber])
            ))
            body.items.append(TLVItem(
                type: TLVTypeCode(rawValue: 0x03),  // advertising identifier
                value: .init(configuration.advertisingIdentifier)
            ))
            if let broadcastKey {
                body.items.append(TLVItem(
                    type: TLVTypeCode(rawValue: 0x04),  // broadcast encryption key
                    value: .init(broadcastKey)
                ))
            }
            return response(request, .success, body: Data(body.data))
        } catch {
            return response(request, Self.status(for: error))
        }
    }
}

// MARK: - Request Body

/// The parameters of a write or timed write request body.
private struct WriteParameters {

    var value: CharacteristicValue?
    var authorizationData: Data?
    var timeToLive: UInt8?
    var remote = false
    var returnResponse = false

    /// Parses a request body, ignoring unsupported parameters.
    init?(body: Data?, format: CharacteristicFormat) {
        guard let body, let container = TLVContainer(data: .init(body)) else { return nil }
        for item in container.items {
            guard let type = BLEPDUParamType(rawValue: item.type.rawValue) else {
                continue  // an accessory must ignore parameters it does not support
            }
            let value = Data(item.value)
            switch type {
            case .value:
                guard let decoded = CharacteristicValue(bleData: value, format: format) else {
                    return nil
                }
                self.value = decoded
            case .additionalAuthorizationData:
                self.authorizationData = value
            case .ttl:
                guard value.count == 1 else { return nil }
                self.timeToLive = Array(value)[0]
            case .origin:
                guard value.count == 1 else { return nil }
                self.remote = Array(value)[0] == 0x01
            case .returnResponse:
                guard value.count == 1 else { return nil }
                self.returnResponse = Array(value)[0] == 0x01
            default:
                continue
            }
        }
    }
}


// MARK: - Configuration Parameters

/// The parameters of a characteristic configuration request body (Table 7-28).
private struct ConfigurationParameters {

    var properties: UInt16?
    var broadcastInterval: BLEBroadcastInterval?

    init?(body: Data?) {
        guard let body else {
            return  // an empty body reads the current configuration
        }
        guard let container = TLVContainer(data: .init(body)) else { return nil }
        for item in container.items {
            let value = Data(item.value)
            switch item.type.rawValue {
            case 0x01:  // HAP-Characteristic-Configuration-Param-Properties
                guard value.count == 2 else { return nil }
                let bytes = Array(value)
                let properties = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
                // Reserved property bits must be rejected.
                guard BLECharacteristicConfigurationProperties(rawValue: properties)
                    .isSubset(of: .broadcastNotification)
                else { return nil }
                self.properties = properties
            case 0x02:  // HAP-Characteristic-Configuration-Param-Broadcast-Interval
                guard value.count == 1,
                      let interval = BLEBroadcastInterval(rawValue: Array(value)[0])
                else { return nil }
                self.broadcastInterval = interval
            default:
                continue
            }
        }
    }
}

/// The parameters of a protocol configuration request body (Table 7-32).
private struct ProtocolConfigurationParameters {

    var generateBroadcastEncryptionKey = false
    var getAllParams = false
    var advertisingIdentifier: Data?

    init?(body: Data?) {
        guard let body, let container = TLVContainer(data: .init(body)) else { return nil }
        for item in container.items {
            let value = Data(item.value)
            switch item.type.rawValue {
            case 0x01:  // Generate-Broadcast-Encryption-Key
                generateBroadcastEncryptionKey = true
            case 0x02:  // Get-All-Params
                getAllParams = true
            case 0x03:  // Set-Accessory-Advertising-Identifier
                guard value.count == 6 else { return nil }
                advertisingIdentifier = value
            default:
                continue
            }
        }
    }
}

// MARK: - Responses

private extension BLEProcedureServer {

    func response(
        _ request: BLEPDURequest,
        _ status: BLEPDUStatus
    ) -> BLEPDUResponse {
        BLEPDUResponse(transactionID: request.transactionID, status: status)
    }

    func response(
        _ request: BLEPDURequest,
        _ status: BLEPDUStatus,
        body: Data
    ) -> BLEPDUResponse {
        BLEPDUResponse(transactionID: request.transactionID, status: status, body: body)
    }

    /// Maps an application error to a HAP status code.
    static func status(for error: HAPError) -> BLEPDUStatus {
        switch error {
        case .notAuthorized: .insufficientAuthorization
        case .outOfResources: .maxProcedures
        case .unknown, .invalidState, .invalidData, .busy: .invalidRequest
        }
    }
}
