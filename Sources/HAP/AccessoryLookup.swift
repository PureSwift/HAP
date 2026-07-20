/// Instance ID lookup in an accessory's attribute database.
public extension Accessory {

    /// The service with the given instance ID, or `nil`.
    func service(iid: UInt64) -> Service? {
        services?.first { $0.iid == iid }
    }

    /// The characteristic with the given instance ID and its owning service, or `nil`.
    func characteristic(iid: UInt64) -> (characteristic: Characteristic, service: Service)? {
        for service in services ?? [] {
            if let characteristic = service.characteristics?.first(where: { $0.iid == iid }) {
                return (characteristic, service)
            }
        }
        return nil
    }

    /// The characteristic with the given type in the given service type, or `nil`.
    ///
    /// Useful for locating well-known characteristics, e.g. the Identify characteristic
    /// of the Accessory Information service.
    func characteristic(
        _ characteristicType: HAPUUID,
        in serviceType: HAPUUID
    ) -> (characteristic: Characteristic, service: Service)? {
        for service in services ?? [] where service.serviceType == serviceType {
            if let characteristic = service.characteristics?.first(
                where: { $0.characteristicType == characteristicType }
            ) {
                return (characteristic, service)
            }
        }
        return nil
    }
}
