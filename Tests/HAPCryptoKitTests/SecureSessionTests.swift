import Testing
import HAP
@testable import HAPCryptoKit

@Suite
struct SecureSessionTests {

    let provider = SwiftCryptoProvider()

    /// A matched pair of accessory and (simulated) controller sessions.
    func makeSessions() -> (
        accessory: SecureSession<SwiftCryptoProvider>,
        controller: SecureSession<SwiftCryptoProvider>
    ) {
        let accessoryToController = Data([UInt8](repeating: 0x0A, count: 32))
        let controllerToAccessory = Data([UInt8](repeating: 0x0B, count: 32))
        let accessory = SecureSession(
            crypto: provider,
            encryptKey: accessoryToController,
            decryptKey: controllerToAccessory
        )
        // The controller's channel directions are mirrored.
        let controller = SecureSession(
            crypto: provider,
            encryptKey: controllerToAccessory,
            decryptKey: accessoryToController
        )
        return (accessory, controller)
    }

    @Test
    func bidirectionalRoundtrip() throws {
        var (accessory, controller) = makeSessions()
        for index in 0 ..< 5 {
            let event = Data(Array("event \(index)".utf8))
            let sealed = try accessory.encrypt(event)
            #expect(try controller.decrypt(sealed) == event)

            let command = Data(Array("command \(index)".utf8))
            let sealedCommand = try controller.encrypt(command)
            #expect(try accessory.decrypt(sealedCommand) == command)
        }
    }

    @Test
    func nonceAdvancesPerMessage() throws {
        var (accessory, _) = makeSessions()
        let message = Data(Array("same message".utf8))
        let first = try accessory.encrypt(message)
        let second = try accessory.encrypt(message)
        #expect(first != second)
    }

    @Test
    func outOfOrderMessageFails() throws {
        var (accessory, controller) = makeSessions()
        _ = try accessory.encrypt(Data(Array("first".utf8)))  // dropped message
        let second = try accessory.encrypt(Data(Array("second".utf8)))
        #expect(throws: HAPError.notAuthorized) {
            try controller.decrypt(second)  // nonce mismatch
        }
    }

    @Test
    func pairVerifyKeysMatchControlChannel() throws {
        let sharedSecret = Data([UInt8](repeating: 0x42, count: 32))
        let result = PairVerifyResult(
            controllerIdentifier: "controller",
            sharedSecret: sharedSecret,
            sessionKey: Data([UInt8](repeating: 0, count: 32))
        )
        var accessory = SecureSession(crypto: provider, pairVerify: result)
        let keys = result.controlChannelKeys(using: provider)
        var controller = SecureSession(
            crypto: provider,
            encryptKey: keys.controllerToAccessory,
            decryptKey: keys.accessoryToController
        )
        let message = Data(Array("hello".utf8))
        #expect(try controller.decrypt(try accessory.encrypt(message)) == message)
    }

    // MARK: HAP over IP Frames

    @Test
    func singleFrameRoundtrip() throws {
        var (accessory, controller) = makeSessions()
        let message = Data(Array("HTTP/1.1 200 OK\r\n\r\n".utf8))
        let frames = try accessory.encryptFrames(message)
        #expect(frames.count == 2 + message.count + 16)
        #expect(try controller.decryptFrame(frames) == message)
    }

    @Test
    func largeMessageSplitsIntoFrames() throws {
        var (accessory, controller) = makeSessions()
        let message = Data((0 ..< 3000).map { UInt8(truncatingIfNeeded: $0) })
        let frames = Array(try accessory.encryptFrames(message))

        // 3000 bytes -> 1024 + 1024 + 952 plaintext frames.
        var decrypted = [UInt8]()
        var offset = 0
        var frameCount = 0
        while offset < frames.count {
            let length = Int(frames[offset]) | Int(frames[offset + 1]) << 8
            #expect(length <= SecureSession<SwiftCryptoProvider>.maximumFrameLength)
            let frame = Data(frames[offset ..< offset + 2 + length + 16])
            decrypted.append(contentsOf: try controller.decryptFrame(frame))
            offset += 2 + length + 16
            frameCount += 1
        }
        #expect(frameCount == 3)
        #expect(Data(decrypted) == message)
    }

    @Test
    func tamperedLengthPrefixFails() throws {
        var (accessory, controller) = makeSessions()
        let message = Data([UInt8](repeating: 0x55, count: 100))
        var frame = Array(try accessory.encryptFrames(message))
        // Shrink the claimed length; the length prefix is authenticated, and the
        // truncated ciphertext no longer matches the tag.
        frame[0] = 90
        let truncated = Data(frame[0 ..< (2 + 90 + 16)])
        #expect(throws: HAPError.notAuthorized) {
            try controller.decryptFrame(truncated)
        }
    }

    @Test
    func malformedFrameRejected() {
        var (_, controller) = makeSessions()
        #expect(throws: HAPError.invalidData) {
            try controller.decryptFrame(Data([0x05, 0x00, 0x01]))  // too short
        }
        // Length exceeding the maximum frame length.
        var oversized = [UInt8](repeating: 0, count: 2 + 2000 + 16)
        oversized[0] = 0xD0
        oversized[1] = 0x07  // 2000
        #expect(throws: HAPError.invalidData) {
            try controller.decryptFrame(Data(oversized))
        }
    }
}
