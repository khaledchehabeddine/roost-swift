import Foundation
import Roost
import XCTest

private struct StorageFailure: Error {}

private final class MemoryStorage: SecureStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    // Tests inject failures between synchronous calls, never during a callback.
    var failNextLoad = false
    var loseNextStoreReply = false

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
        if loseNextStoreReply {
            loseNextStoreReply = false
            throw StorageFailure()
        }
    }

    func load(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if failNextLoad {
            failNextLoad = false
            throw StorageFailure()
        }
        return values[key]
    }

    func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}

final class StorageTests: XCTestCase {
    func testUnexpectedCallbackErrorLeavesClientUsable() throws {
        let storage = MemoryStorage()
        let client = Client(storage: storage)
        storage.failNextLoad = true
        XCTAssertThrowsError(try client.identity().hasIdentity()) { error in
            guard case ClientError.Storage = error else { return XCTFail("\(error)") }
        }
        XCTAssertFalse(try client.identity().hasIdentity())
    }

    func testLostWriteReplyRecoversOriginalIdentityAcrossReopen() throws {
        let storage = MemoryStorage()
        let client = Client(storage: storage)
        let prepared = try client.identity().prepareGenerateIdentity()
        _ = try client.commitOperation(identifier: prepared.operation.identifier)
        storage.loseNextStoreReply = true
        XCTAssertThrowsError(try client.finalizeOperation(identifier: prepared.operation.identifier)) { error in
            guard case ClientError.Storage = error else { return XCTFail("\(error)") }
        }
        let reopened = Client(storage: storage)
        _ = try reopened.finalizeOperation(identifier: prepared.operation.identifier)
        XCTAssertEqual(try reopened.identity().loadIdentity().ed25519VerifyingKey,
                       prepared.identity.ed25519VerifyingKey)
        XCTAssertTrue(try reopened.unfinishedOperations().isEmpty)
    }
}
