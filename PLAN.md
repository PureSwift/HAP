# HAP Swift Implementation Plan

Implementation of the HomeKit Accessory Protocol Specification (Non-Commercial Version, Release R2, 2019-07-26) in pure Swift, modeled after Apple's [HomeKitADK](https://github.com/apple/HomeKitADK), with the Platform Abstraction Layer (PAL) — **including crypto** — expressed as Swift protocols. The core library is designed to compile under **Embedded Swift** for bare-metal targets (Cortex-M, RISC-V, ESP32) while remaining fully usable on hosted platforms.

## Reference documents

- **Non-Commercial R2 (2019-07-26)** — primary reference. Newer attribute catalog
  (45 services §8, 128 characteristics §9). Section numbers in this plan refer to R2
  unless marked otherwise.
- **Commercial R13 (2018-11-10)** — secondary reference for details R2 omits:
  - **§4.2.2–4.4 Setup ID, setup hash, setup payload format (`X-HM://`), QR code & NFC
    requirements** — R2 only covers the setup code itself.
  - Extra procedure diagrams (Figures 7-1…7-12) for the BLE procedures.
  - Out of scope (commercial-only, not implemented): WAC2 (§3.3.1), Software
    Authentication (§3.6, §5.15), HAP over iCloud (§8), App Requirements (§15).
  - Numbering shift: R13 services = §9, characteristics = §10, TLV appendix = §16
    (vs. §8/§9/§14 in R2). The ADK sources and existing Swift doc comments cite R14
    numbering, which matches R2's layout.

## Dependencies

| Package | Version | Role |
|---|---|---|
| [PureSwift/Bluetooth](https://github.com/PureSwift/Bluetooth) | 7.5.1 | `BluetoothUUID`, `BluetoothAddress`, `UInt128`; `BluetoothGAP` for advertising data units; `BluetoothGATT` for GATT/descriptor types. Embedded Swift support. |
| [PureSwift/GATT](https://github.com/PureSwift/GATT) | 3.4.1 (trait `BluetoothGATT`) | **The BLE server layer.** `GATTPeripheral` (pure Swift GATT server) + `PeripheralManager` abstraction; on embedded it runs via a non-blocking `run()` from the platform run loop (no threads/async). Platform backends: `DarwinGATT` (CoreBluetooth), `BluetoothLinux` (BlueZ), BTStack / NimBLE / Zephyr for MCUs. |
| [PureSwift/TLVCoding](https://github.com/PureSwift/TLVCoding) | 3.0.0 | TLV8 encode/decode via `TLVCodable` protocol + macros (no Codable, no Foundation) — the backbone of pairing payloads and BLE PDU bodies. |
| [PureSwift/swift-embedded-foundation](https://github.com/PureSwift/swift-embedded-foundation) | 0.1.0 | `FoundationEmbedded` product: `Data`, `UUID`, `Date`, `URL`, … mirroring Foundation's API for bare-metal targets; source-compatible with real Foundation on hosted platforms. |
| [apple/swift-binary-parsing](https://github.com/apple/swift-binary-parsing) | 0.0.2 | `ParserSpan`-based safe parsing for HAP-BLE PDUs, HTTP messages, advertisement payloads, and the setup payload. TLVCoding integrates it on Swift 6.2+ (env `SWIFTPM_ENABLE_BINARY_PARSING`). |
| swift-crypto (hosted reference provider only) | — | Backs the default `CryptoProvider` on macOS/Linux. **Not** a dependency of the core target (BoringSSL doesn't build for embedded). |

Toolchain note: swift-embedded-foundation declares `swift-tools-version: 6.3`, so a Swift 6.3 toolchain is required to resolve the graph even though this package's manifest stays at 6.2. Bluetooth/FoundationEmbedded use `UInt128`, which raises hosted platform floors to macOS 15 / iOS 18.

**Current build workaround**: build with `SWIFTPM_ENABLE_MACROS=0` (e.g. `SWIFTPM_ENABLE_MACROS=0 swift build`). The swift-syntax pins across the dependency graph are momentarily incompatible — Bluetooth 7.5.1 pins 600–601, swift-binary-parsing 0.0.2 pins 602, TLVCoding 3.0.0 pins 603 — and disabling macros removes swift-syntax from the graph entirely. Once Bluetooth/TLVCoding widen their ranges, drop the env var and re-add swift-binary-parsing as a direct dependency. Until then, `TLVCodable` conformances are hand-written rather than macro-generated (which the plan needed for Embedded Swift anyway).

## Embedded Swift ground rules

These constrain every API decision in the core target:

1. **No existentials** — no `any` types in the core. Type erasure via enums (e.g. `Characteristic`) or generics, never protocol boxes. Untyped `throws` implies an `any Error` existential, so:
2. **Typed throws everywhere** — `throws(HAPError)` (the pattern swift-embedded-foundation itself uses).
3. **No Codable, no reflection** — TLV via `TLVCodable` conformances (macro-generated or hand-written); JSON (IP transport) via a hand-rolled serializer over the attribute DB, not `JSONEncoder`.
4. **No Foundation in the core** — `import FoundationEmbedded` (or a conditional shim `#if canImport(FoundationEmbedded)` while transitioning existing files off `import Foundation`).
5. **Allocation-conscious, not allocation-free** — classes and ARC are fine (Embedded Swift supports them); avoid unbounded intermediate buffers in hot paths; parse in place with `ParserSpan`.
6. **No async/await in the core** — Embedded Swift concurrency support is immature and executor-heavy for MCUs. The core is a **sans-I/O, synchronous, event-driven state machine** (mirroring the ADK's run-loop model): PAL implementations deliver events via plain callbacks. A hosted convenience layer may wrap this in async later.
7. **Everything `Sendable`, strict concurrency clean** — cheap now, required later.

## Architecture

```
┌──────────────────────────────────────────────────┐
│ Application (accessory definition, callbacks)    │
├──────────────────────────────────────────────────┤
│ HAP core (sans-I/O, Embedded Swift compatible)   │
│  attribute DB · TLV8 · pairing · session         │
│  state machines · BLE PDU · HTTP/JSON codecs     │
├──────────────────────────────────────────────────┤
│ PAL — Swift protocols                            │
│  CryptoProvider · KeyValueStore · Clock/Timer    │
│  BLEPeripheralManager · AccessorySetup           │
│  ServiceDiscovery · TCPStreamManager (IP only)   │
├───────────────┬────────────────┬─────────────────┤
│ Embedded impl │ HAPCryptoKit   │ HAPDarwin       │
│ (user: HW     │ (swift-crypto, │ (CoreBluetooth, │
│  crypto, SDK  │  hosted ref.)  │  Network.fw,    │
│  BLE stack)   │                │  dnssd)         │
└───────────────┴────────────────┴─────────────────┘
```

| Target | Contents | Embedded? |
|---|---|---|
| `HAP` | Core types, attribute DB, TLV8 conformances, pairing/session state machines, BLE PDU + procedures, IP wire formats, PAL protocol definitions | ✅ |
| `HAPCryptoKit` | Reference `CryptoProvider` backed by swift-crypto + SRP-6a implementation | hosted only |
| `HAPDarwin` (later) | Reference transport PAL: `DarwinGATT` peripheral, Network.framework, dnssd | hosted only |
| `HAPTests` | Spec test vectors, state-machine tests with mock PAL | hosted only |

## Phase 1 — Core model completion (spec §2, §14)

1. **De-Foundation the existing sources**: replace `import Foundation` with `FoundationEmbedded`, replace `UUID` with a `HAPUUID` type backed by `UInt128`/`BluetoothUUID` implementing the short-UUID scheme `XXXXXXXX-0000-1000-8000-0026BB765291` (§6.6.1) with compact serialization; adopt `throws(HAPError)` in all callback signatures.
2. **TLV8 layer** (§14.1): `TLVCodable` conformances for the pairing TLV types (kTLVType_*, §5.15); verify fragmentation (255-byte items) and coalescing against the §14.1.2 examples and ADK behavior.
3. **Characteristic unification**: `Characteristic` enum with a case per format wrapping the existing per-format structs (mandatory — no existentials). Fix `Service.characteristics: [Any]?`.
4. **Service catalog** (§8) and **characteristic catalog** (§9): Apple-defined services/characteristics as static definitions with formats, units, ranges, permissions.
5. **Attribute database validation** (§2.6, ADK `HAPAccessoryValidation.c`): IID rules, required services, bridge rules.

## Phase 2 — PAL as Swift protocols

| ADK header | Swift protocol | Notes |
|---|---|---|
| `PAL/Crypto` (`HAPCrypto.h`) | **`CryptoProvider`** | The ADK already treats crypto as PAL (OpenSSL/mbedTLS backends) — mirror that. Requirements: SHA-512, HKDF-SHA-512, ChaCha20-Poly1305 seal/open, Ed25519 keygen/sign/verify, X25519 (Curve25519 DH), and SRP-6a server ops (start/verify/shared-secret, 3072-bit group). Embedded targets plug in hardware acceleration or an SDK crypto lib; hosted uses `HAPCryptoKit`. |
| `HAPPlatformKeyValueStore.h` | `KeyValueStore` | Domain/key namespaced blob storage; drives pairing persistence. Embedded: flash/NVS-backed. |
| `HAPPlatformRandomNumber.h` | `RandomNumberSource` | Protocol (not `SystemRandomNumberGenerator`): embedded needs HW TRNG injection, tests need determinism. |
| `HAPPlatformClock.h` / `Timer.h` / `RunLoop.h` | `Clock`, `TimerScheduler` | Monotonic milliseconds + deadline callbacks. No Swift Concurrency (ground rule 6). |
| `HAPPlatformLog.h` | `HAPLogger` | Minimal levelled-log protocol; default no-op. swift-log adapter on hosted. |
| `HAPPlatformAccessorySetup.h` (+Display/NFC) | `AccessorySetupStore`, `AccessorySetupDisplay`, `AccessorySetupNFC` | Setup verifier storage, dynamic QR/NFC payloads. |
| `HAPPlatformBLEPeripheralManager.h` | **Provided by PureSwift/GATT** | The HAP BLE transport binds to GATT's `PeripheralManager` abstraction (`GATTPeripheral` + platform backends) instead of defining its own protocol. HAP-specific needs (dynamic advertising data for GSN/encrypted notifications, per-connection events for session binding, MTU) get a thin adapter — or upstream additions to GATT where generally useful. |
| `HAPPlatformServiceDiscovery.h` | `ServiceDiscovery` | Bonjour `_hap._tcp` TXT records (IP only). |
| `HAPPlatformTCPStreamManager.h` | `TCPStreamManager` / `TCPStream` | Listener + non-blocking byte streams, callback-driven (IP only). |

Deliverable: protocols + in-memory mocks (`MockCryptoProvider` wrapping known-answer vectors, `MockKeyValueStore`, `MockBLEPeripheralManager`, …) mirroring `PAL/Mock`.

## Phase 3 — Crypto & pairing (spec §4, §5)

1. **`HAPCryptoKit` reference provider**: swift-crypto for Ed25519 / X25519 / ChaCha20-Poly1305 / HKDF-SHA-512; hand-implemented **SRP-6a** (RFC 5054, SHA-512, 3072-bit group, §5.5 modifications) with minimal big-integer modexp; validated against the §5.5.2 test vectors.
2. **Setup code / setup payload** (§4; R13 §4.2.2–4.4): setup code format + invalid list, SRP verifier generation, `X-HM://` payload, setup hash, QR/NFC payloads (`ParserSpan`-based builder/parser).
3. **Pair Setup** (§5.6): M1–M6 state machine over TLV8, generic over `CryptoProvider`.
4. **Pair Verify** (§5.7) + **Pair Resume** groundwork (R2 §7.3.7).
5. **Pairings management** (§5.10–5.12): Add/Remove/List, admin rules, persistence via `KeyValueStore`.
6. **Session security** (§5.8–5.9, §6.5.2): ChaCha20-Poly1305 AEAD framing, nonce counters, fragmentation. `Session` gains real state.

Everything here is sans-I/O: fully testable on the host with `MockCryptoProvider`/spec vectors, and it runs unmodified on embedded once a device `CryptoProvider` exists.

## Phase 4 — HAP over Bluetooth LE (spec §7) — primary transport

BLE comes first: it is the transport that matters for Embedded Swift targets, and PureSwift/Bluetooth provides the type vocabulary end-to-end.

1. **HAP-BLE PDU** (§7.3.3): request/response format, control field, fragmentation — parsed/serialized with `ParserSpan`; bodies via TLVCoding.
2. **PDU payloads & procedures** (§7.3.4–7.3.5, R13 Figures 7-1…7-12): signature read, read/write, timed write, write-with-response, configuration, protocol configuration — synchronous state machines per connection.
3. **GATT layout** (§7.4.3–7.4.6): instance-ID descriptors, Protocol Information service, presentation formats — built on `BluetoothGATT` types, registered into a `GATTPeripheral` (or platform `PeripheralManager`).
4. **Advertising** (§7.4.2): wire the existing `BLEAdvertising` model types into `BluetoothGAP` advertising-data units; GSN management, encrypted notification broadcasts, broadcast key HKDF (§7.4.7.3).
5. **Session/GSN rules** (§7.4.1.8), connected/broadcast/disconnected events (§7.4.6), Pair Resume (§7.3.7).

Milestones:
- **Host**: pair with the real Home app on macOS via `DarwinGATT` (CoreBluetooth peripheral).
- **Embedded**: cross-compile the `HAP` target for an MCU (Pi Pico W / ESP32 / nRF52840) with a BTStack/NimBLE/Zephyr-backed `GATTPeripheral` + device `CryptoProvider`, pair from the Home app.

## Phase 5 — HAP over IP (spec §6)

1. **Discovery** (§6.4): TXT record content via `ServiceDiscovery`.
2. **HTTP layer** (§6.2.4): `ParserSpan`-based HTTP/1.1 request parser + response writer (off-the-shelf servers can't do `EVENT/1.0` or the encrypted session layer), callback-driven over `TCPStream`.
3. **Attribute DB JSON** (§6.3, §6.6): hand-rolled JSON writer (no Codable), `/accessories`.
4. **Characteristic access** (§6.7): GET/PUT `/characteristics`, timed writes, write responses, `/identify`, HAP status codes.
5. **Notifications** (§6.8): `EVENT/1.0`, coalescing, per-session subscriptions.

Milestone: pair and control a demo Light Bulb from the Home app over Wi-Fi (`HAPDarwin`: Network.framework + dnssd).

## Phase 6 — Hardening & extras

- Full spec-vector suite; fuzz TLV8/PDU/HTTP parsers (hosted).
- **Embedded CI**: cross-compile the `HAP` target with `-enable-experimental-feature Embedded` for ARM none-eabi in CI to keep the core embedded-clean; hosted CI on macOS + Linux.
- Bridges (§2.5.3.2), dynamic DB updates (config number bump).
- Out of initial scope: HomeKit Data Stream (§6.10), IP Cameras (§11), Remotes (§12).

## Suggested order & rationale

Phases 1→2→3 are strictly sequential. BLE (Phase 4) now precedes IP (Phase 5): the embedded story is the point of this design, BLE is the embedded transport, and the Home-app-over-CoreBluetooth loop on macOS gives the same fast end-to-end validation that IP would have. The pairing core is transport-agnostic either way and fully verified against spec vectors before any transport exists.
