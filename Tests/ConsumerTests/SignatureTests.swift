import CryptoKit
import Foundation
import Roost
import XCTest

final class SignatureTests: XCTestCase {
    func testReturnedSignatureUsesPlatformVerification() throws {
        let context = IdentityContext(secureStorage: MemoryStorage())
        let prepared = try context.prepareIdentityCreation()
        try context.reserveOperation(id: prepared.operationId)
        try context.finalizeOperation(id: prepared.operationId)
        let transcript = Data([0x00, 0x7f, 0x80, 0xff])
        let signature = try context.signAuthenticationTranscript(transcript: transcript)
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: prepared.identity.key.signingKey)
        XCTAssertTrue(key.isValidSignature(signature, for: transcript))
    }
}
