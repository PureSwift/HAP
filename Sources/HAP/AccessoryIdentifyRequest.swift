//
//  AccessoryIdentifyRequest.swift
//  HAP
//
//  Created by Alsey Coleman Miller on 3/1/26.
//

/// An identify request for a HomeKit accessory.
public struct AccessoryIdentifyRequest {
    
    /// Transport type over which the request has been received.
    public var transportType: TransportType

    /// The session over which the request has been received.
    public var session: Session

    /// The accessory that is being identified.
    public var accessory: Accessory

    /// Whether the request appears to have originated from a remote controller (e.g. via Apple TV).
    public var remote: Bool
}
