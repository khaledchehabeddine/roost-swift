import Roost
import XCTest
import CryptoKit
import Foundation

final class EvidenceTests: XCTestCase {
    func testEvidenceAndReturnedSignaturesUsePlatformVerification() throws {
        let domainKey = DomainSigningKey(
            identifier: bytes("domain_signing_key.identifier_hex"),
            verifyingKey: bytes("domain_signing_key.verifying_key_hex"),
            status: .trusted
        )
        let verified = try verifyEvidenceBundle(
            evidenceBundle: bytes("valid.bundle_hex"),
            expectedProfile: .messageTranscriptVersion1,
            domainSigningKeys: [domainKey],
            expectedRelayDomain: bytes("expected_relay_domain_hex"),
            acceptedTimestampSecs: UInt64(value("accepted_timestamp_secs"))!,
            graceWindowSecs: UInt64(value("grace_window_secs"))!
        )
        XCTAssertTrue(verified.evidenceIdentity == bytes("valid.decoded.evidence_identity_hex"))
        XCTAssertTrue(verified.payloadKind == .encryptedText)
        let certificate = bytes("valid.verification_material.sender_certificate_hex")
        let domain = try Curve25519.Signing.PublicKey(rawRepresentation: domainKey.verifyingKey)
        XCTAssertTrue(domain.isValidSignature(bytes("valid.verification_material.sender_certificate_signature_hex"), for: certificate))

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
        XCTAssertTrue(sender.isValidSignature(bytes("valid.verification_material.message_transcript_signature_hex"), for: transcript))
        transcript[transcript.count - 1] ^= 1
        XCTAssertTrue(!sender.isValidSignature(bytes("valid.verification_material.message_transcript_signature_hex"), for: transcript))
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

    private let fixture: [String: Any] = {
        let url = Bundle.module.url(forResource: "evidence_bundles_v1", withExtension: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }()

    private func value(_ path: String) -> String {
        let value = path.split(separator: ".").reduce(fixture as Any) { value, key in
            (value as! [String: Any])[String(key)]!
        }
        return String(describing: value)
    }

    private func bytes(_ key: String) -> Data {
        let hex = value(key)
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
