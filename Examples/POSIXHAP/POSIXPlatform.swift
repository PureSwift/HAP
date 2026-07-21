import Foundation
import HAP

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A monotonic clock backed by `clock_gettime(CLOCK_MONOTONIC)`.
///
/// - Note: Mirrors `HAPPlatformClock` from the ADK.
public final class POSIXClock: PlatformClock, @unchecked Sendable {

    public init() {}


    public var now: HAPTime {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)
        let milliseconds = UInt64(time.tv_sec) * 1000 + UInt64(time.tv_nsec) / 1_000_000
        return HAPTime(rawValue: milliseconds)
    }
}

// MARK: -

/// A cryptographically secure random source backed by the system generator.
public struct POSIXRandom: RandomNumberSource {

    public init() {}


    public func fill(_ buffer: inout [UInt8]) {
        var generator = SystemRandomNumberGenerator()
        for index in buffer.indices {
            buffer[index] = UInt8.random(in: .min ... .max, using: &generator)
        }
    }
}

// MARK: -

/// A key-value store that persists each value as a file.
///
/// Values live at `<directory>/<domain>/<key>`, so pairings and accessory identity survive
/// restarts. Suitable for macOS and Linux; an embedded target would back this with flash.
///
/// - Note: Mirrors `HAPPlatformKeyValueStore` from the ADK.
public final class FileKeyValueStore: KeyValueStore {

    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func value(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) -> Data? {
        let url = url(for: key, in: domain)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let data = fileManager.contents(atPath: url.path) else {
            throw .unknown
        }
        return data
    }

    public func setValue(
        _ value: Data,
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) {
        do {
            try createDomain(domain)
            try value.write(to: url(for: key, in: domain), options: .atomic)
        } catch {
            throw .unknown
        }
    }

    public func removeValue(
        for key: KeyValueStoreKey,
        in domain: KeyValueStoreDomain
    ) throws(HAPError) {
        let url = url(for: key, in: domain)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw .unknown
        }
    }

    public func enumerateKeys(
        in domain: KeyValueStoreDomain,
        _ body: (KeyValueStoreKey) throws(HAPError) -> Bool
    ) throws(HAPError) {
        let directory = url(for: domain)
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return  // an absent domain simply has no keys
        }
        for name in names.sorted() {
            guard let rawValue = UInt8(name) else { continue }
            guard try body(KeyValueStoreKey(rawValue: rawValue)) else { return }
        }
    }

    public func removeAll(in domain: KeyValueStoreDomain) throws(HAPError) {
        let directory = url(for: domain)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            throw .unknown
        }
    }

    private func createDomain(_ domain: KeyValueStoreDomain) throws {
        try fileManager.createDirectory(at: url(for: domain), withIntermediateDirectories: true)
    }

    private func url(for domain: KeyValueStoreDomain) -> URL {
        directory.appendingPathComponent(String(domain.rawValue))
    }

    private func url(for key: KeyValueStoreKey, in domain: KeyValueStoreDomain) -> URL {
        url(for: domain).appendingPathComponent(String(key.rawValue))
    }
}
