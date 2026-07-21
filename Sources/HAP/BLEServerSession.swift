/// The surface a HAP-BLE transport binding drives.
///
/// ``BLEAccessoryServer`` conforms to this; the abstraction keeps
/// ``BLEPeripheralServer`` generic over the server's own type parameters and lets bindings
/// be tested against a stub.
public protocol BLEServerSession: AnyObject {

    /// The accessory whose attribute database is served.
    var accessory: Accessory { get }

    /// Registers a new controller connection.
    func connect(_ connection: UInt64)

    /// Removes a controller connection, ending the global state number increment cycle.
    func disconnect(_ connection: UInt64) throws(HAPError)

    /// Handles a GATT write to a HAP characteristic.
    ///
    /// - Throws: An error requires the transport to drop the connection.
    func handleWrite(
        connection: UInt64,
        characteristicIID: UInt16,
        data: Data
    ) throws(HAPError)

    /// Returns the response to the last completed request on a connection.
    func readResponse(connection: UInt64) -> Data?

    /// The regular advertisement payload for the current state.
    func advertisementData() throws(HAPError) -> Data
}

// MARK: -

extension BLEAccessoryServer: BLEServerSession {}
