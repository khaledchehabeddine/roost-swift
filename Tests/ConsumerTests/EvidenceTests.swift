import Roost
import XCTest
import CryptoKit
import Foundation

final class EvidenceTests: XCTestCase {
    func testEvidenceAndReturnedSignaturesUsePlatformVerification() throws {
        let domainKey = DomainSigningKey(
            identifier: Data("test-domain".utf8),
            verifyingKey: bytes("6556ea860463d074ae046736e1f20f6c78f7a26e31518d1fe7f645150aaa6ad1"),
            status: .trusted
        )
        let verified = try verifyEvidenceBundle(
            evidenceBundle: bytes("01011009090909090909090909090909090909bc7cbcb5636375fa1d82434d466724d92377f53b980695dd49d26d0ce1" +
                "2205a50221000000004000800000000000000081fca7ffbc3100200000001b636f6e7465787420666f7220616e206162" +
                "757365207265706f7274007b41657468657253656e64657243657274696669636174652d76323a020b746573742d646f" +
                "6d61696e0a72656c61792e7465737457f24707f390532aa6598f61c43f3bc2dae984525359cb43fc13db947e93f63e65" +
                "e8f9b0bc6eae124169f0576f97362d295a8cf5f770b45e14357ce647d33eec00000000655577a0409ed439e636de0aab" +
                "b9ec5e6c0562d1c2892d1a1679897b3f4d1583bcc4abfc014821307b3bb6e35ec85fe66bca2c2e46ffd56f0bd533e434" +
                "69659c01f985450640340624ac228577b9d3823baec5f873a09708c2e88d4f83ce4f2660911f7606b89a1b0b0f82399c" +
                "1137947e6fc1c1bec30553cfdc435559c1d76007741143e40f"),
            expectedProfile: .messageTranscriptVersion1,
            domainSigningKeys: [domainKey],
            expectedRelayDomain: Data("relay.test".utf8),
            acceptedTimestampSecs: 1700000000,
            graceWindowSecs: 0
        )
        XCTAssertTrue(verified.evidenceIdentity == bytes("a7af7974cb7c5c3c770baf1b946f8d7d69a295068d99b78425b1df538a6aa489"))
        XCTAssertTrue(verified.payloadKind == .encryptedText)
        let certificate = bytes("41657468657253656e64657243657274696669636174652d76323a020b746573742d646f6d61696e0a72656c61792e74" +
                "65737457f24707f390532aa6598f61c43f3bc2dae984525359cb43fc13db947e93f63e65e8f9b0bc6eae124169f0576f" +
                "97362d295a8cf5f770b45e14357ce647d33eec00000000655577a0")
        let domain = try Curve25519.Signing.PublicKey(rawRepresentation: domainKey.verifyingKey)
        XCTAssertTrue(domain.isValidSignature(bytes("9ed439e636de0aabb9ec5e6c0562d1c2892d1a1679897b3f4d1583bcc4abfc014821307b3bb6e35ec85fe66bca2c2e46ffd56f0bd533e43469659c01f9854506"), for: certificate))

        // Rebuild the signed transcript from the fields returned across FFI.
        var padded = Data()
        padded.appendBigEndian(UInt32(verified.plaintext.count))
        padded.append(verified.plaintext)
        var bucket = 32
        while bucket < padded.count { bucket *= 2 }
        padded.append(Data(repeating: 0, count: bucket - padded.count))
        var transcript = Data("AetherMessageTranscript-v1:".utf8)
        transcript.appendBigEndian(UInt32(verified.sessionKey.count))
        transcript.append(verified.sessionKey)
        transcript.append(verified.recipientIdentityVerifyingKey)
        transcript.append(verified.messageId)
        transcript.appendBigEndian(verified.timestampMillis)
        transcript.append(0)
        transcript.appendBigEndian(UInt32(padded.count))
        transcript.append(padded)
        transcript.appendBigEndian(UInt32(certificate.count))
        transcript.append(certificate)
        let sender = try Curve25519.Signing.PublicKey(
            rawRepresentation: verified.senderIdentityKey.ed25519VerifyingKey
        )
        let messageSignature = bytes("340624ac228577b9d3823baec5f873a09708c2e88d4f83ce4f2660911f7606b89a1b0b0f82399c1137947e6fc1c1bec30553cfdc435559c1d76007741143e40f")
        XCTAssertTrue(sender.isValidSignature(messageSignature, for: transcript))
        transcript[transcript.count - 1] ^= 1
        XCTAssertTrue(!sender.isValidSignature(messageSignature, for: transcript))
        // Verify fresh signature bytes returned by the generated signer binding.
        let client = Client(storage: InMemorySecureStorage())
        let prepared = try client.identity().prepareGenerateIdentity()
        _ = try client.commitOperation(identifier: prepared.operation.identifier)
        _ = try client.finalizeOperation(identifier: prepared.operation.identifier)
        let authentication = Data([0x00, 0x7f, 0x80, 0xff])
        let signature = try client.identity().signAuthenticationTranscript(transcript: authentication)
        let key = try Curve25519.Signing.PublicKey(
            rawRepresentation: prepared.identity.ed25519VerifyingKey
        )
        XCTAssertTrue(key.isValidSignature(signature, for: authentication))
    }

    private func bytes(_ hex: String) -> Data {
        return Data(stride(from: 0, to: hex.count, by: 2).map { index in
            let start = hex.index(hex.startIndex, offsetBy: index)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)!
        })
    }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
