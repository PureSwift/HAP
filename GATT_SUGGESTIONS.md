# Suggested changes to PureSwift/GATT

Gaps found while binding this HAP-BLE stack to `PeripheralManager` (GATT 3.4.1). Ordered
by how much they block a correct HAP accessory.

## 1. Connection lifecycle callbacks (blocking)

`PeripheralManager` exposes `willRead` / `willWrite` / `didWrite` but no way to observe a
central **connecting or disconnecting**. HAP needs both:

- **On connect**: stop advertising (§7.4.1.4 — an accessory must not advertise while a
  controller is connected) and allocate per-connection state (PDU assembler, secure session).
- **On disconnect**: end the GSN increment cycle (§7.4.1.8), tear down the secure session,
  and resume advertising.

Today the only signal is polling the `connections: Set<Central>` set and diffing it, which is
racy and misses fast connect/disconnect pairs.

**Proposed:**
```swift
var didConnect: ((Central) -> ())? { get set }
var didDisconnect: ((Central) -> ())? { get set }
```
`GATTPeripheral` already tracks `storage.connections`; emit these when that set changes.
`DarwinPeripheral` can bridge `CBPeripheralManagerDelegate`'s
`didSubscribeTo` / `centralDidUnsubscribe` or the connection-state transitions.

## 2. MTU per connection (needed for correct fragmentation)

HAP-BLE fragments PDUs to the negotiated ATT MTU (§7.3.3.5). `GATTReadRequest` /
`GATTWriteRequest` carry `maximumUpdateValueLength`, but there's no way to query the current
MTU for a `Central` **outside** a request — needed when the accessory initiates an indication
and must pre-fragment.

**Proposed:**
```swift
func maximumTransmissionUnit(for central: Central) throws(Error) -> MaximumTransmissionUnit
```

## 3. Indication vs. notification, with confirmation (needed for HAP connected events)

HAP connected events (§7.4.6.1) require **indications** (confirmed), not notifications.
`write(_:forCharacteristic:)` "optionally emits notifications if configured", but the API
doesn't let the caller (a) require indication specifically, or (b) learn that the controller
confirmed. HAP treats the GSN as advanced only once the controller has acknowledged.

**Proposed:** either honor the characteristic's declared `.indicate` property automatically
(preferred) and expose a completion, or add:
```swift
func indicate(_ value: Data, forCharacteristic handle: UInt16, for central: Central,
              confirmation: @escaping (Result<Void, Error>) -> ())
```

## 4. Handle → attribute reverse lookup (ergonomics)

`add(service:)` returns `(UInt16, [UInt16])` — the service handle and a flat array of
characteristic handles. There is no descriptor handle in the return, and the flat array forces
the caller to re-walk the input service to correlate handles with UUIDs. For HAP, every write
arrives by **handle**, and the server routes by **HAP instance ID**, so the binding must build
and maintain a `handle → (serviceIID, charIID)` map by hand.

**Proposed:** return a structured result mirroring the input tree, e.g.
```swift
struct AddedService { let handle: UInt16
                      let characteristics: [(handle: UInt16, descriptors: [UInt16])] }
func add(service: …) throws(Error) -> AddedService
```
(Descriptor handles are also needed — HAP publishes a Characteristic Instance ID descriptor
per characteristic and currently can't recover its handle.)

## 5. `willRead` returning a value (ergonomics)

HAP-BLE is write-then-read on the same characteristic: the controller writes a request PDU,
then reads the response. Today the response must be staged via `write(_:forCharacteristic:)`
inside `didWrite`, then served from stored value on the next read. A `willRead` that can
**return** the bytes (not just an `ATTError?`) would let the binding compute the response
lazily and avoid the stored-value round trip:
```swift
var willRead: ((GATTReadRequest<Central, Data>) -> Result<Data, ATTError>)? { get set }
```

---

Items 1–3 are functional blockers for a spec-complete HAP accessory; 4–5 are ergonomics that
would remove hand-maintained state from every binding. Items 1, 2, and 4 are the highest
leverage.
