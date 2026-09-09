import Roost
import XCTest
import Foundation

final class TransportBindingTests: XCTestCase {
    func testBinaryBindingAuthenticatesSlices() throws {
        let alice = Client(storage: InMemorySecureStorage())
        let bob = Client(storage: InMemorySecureStorage())
        let aliceIdentity = try alice.identity().prepareGenerateIdentity()
        try complete(alice, aliceIdentity.operation)
        let bobIdentity = try bob.identity().prepareGenerateIdentity()
        try complete(bob, bobIdentity.operation)
        let signedPrekey = try bob.identity().prepareRotateSignedPrekeyNow()
        try complete(bob, signedPrekey.operation)
        let publication = try bob.identity().currentPublicationBundle()
        let selection = PreKeySelection(
            signedPrekeyIdentifier: publication.signedPrekey.identifier,
            oneTimePrekeyIdentifier: nil
        )

        // Data slices can have a nonzero startIndex. Include NUL and high-bit bytes.
        let backing = Data([0x55, 0x00, 0x7f, 0x80, 0xff, 0x55])
        let initiation = try alice.messaging().initiateSession(
            sessionKey: Data(repeating: 0x58, count: 16),
            responderIdentity: bobIdentity.identity,
            responderPublication: publication,
            responderOneTimePrekey: nil,
            senderCertificate: Data(),
            senderSignature: Data(),
            plaintext: Data("binding conversion".utf8),
            transportBinding: TransportBinding(bytes: backing[1..<5])
        )
        let hint = try bob.messaging().initiatorIdentityHint(
            message: initiation.message,
            transportBinding: TransportBinding(bytes: Data([0x00, 0x7f, 0x80, 0xff])),
            prekeySelection: selection
        )
        XCTAssertEqual(hint.ed25519VerifyingKey, aliceIdentity.identity.ed25519VerifyingKey)
        do {
            _ = try bob.messaging().initiatorIdentityHint(
                message: initiation.message,
                transportBinding: TransportBinding(bytes: Data([0x00, 0x7f, 0x81, 0xff])),
                prekeySelection: selection
            )
            XCTFail("changed binding byte authenticated")
        } catch ClientError.AuthenticationFailed { }
    }

    private func complete(_ client: Client, _ operation: KeyStoreOperation) throws {
        _ = try client.commitOperation(identifier: operation.identifier)
        _ = try client.finalizeOperation(identifier: operation.identifier)
    }
}
