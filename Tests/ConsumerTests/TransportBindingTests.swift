import Roost
import XCTest
import Foundation

final class TransportBindingTests: XCTestCase {
    func testBinaryBindingAuthenticatesSlices() throws {
        let alice = IdentityContext(secureStorage: MemoryStorage())
        let bob = IdentityContext(secureStorage: MemoryStorage())
        let aliceIdentity = try alice.prepareIdentityCreation()
        try complete(alice, aliceIdentity.operationId)
        let bobIdentity = try bob.prepareIdentityCreation()
        try complete(bob, bobIdentity.operationId)
        let signedPrekey = try bob.prepareSignedPrekeyRotation()
        try complete(bob, signedPrekey.operationId)
        let publication = try bob.currentPublication()
        let selection = PreKeySelection(
            signedPrekeyId: publication.signedPrekey.id,
            oneTimePrekeyId: nil
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
        XCTAssertEqual(hint, aliceIdentity.identity)
        do {
            _ = try bob.messaging().initiatorIdentityHint(
                message: initiation.message,
                transportBinding: TransportBinding(bytes: Data([0x00, 0x7f, 0x81, 0xff])),
                prekeySelection: selection
            )
            XCTFail("changed binding byte authenticated")
        } catch RoostError.AuthenticationFailed { }
    }

    private func complete(_ context: IdentityContext, _ id: OperationId) throws {
        try context.reserveOperation(id: id)
        try context.finalizeOperation(id: id)
    }
}
