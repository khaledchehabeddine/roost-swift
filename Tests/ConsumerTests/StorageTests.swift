import Foundation
import Roost
import XCTest

private struct StorageFailure: Error {}

final class MemoryStorage: SecureStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    // Tests inject failures between synchronous calls, never during a callback.
    var failNextLoad = false
    var loseNextSaveReply = false

    func save(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
        if loseNextSaveReply {
            loseNextSaveReply = false
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

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}

final class StorageTests: XCTestCase {
    func testUnexpectedCallbackErrorLeavesContextUsable() throws {
        let storage = MemoryStorage()
        let context = IdentityContext(secureStorage: storage)
        storage.failNextLoad = true
        XCTAssertThrowsError(try context.identity()) { error in
            guard case RoostError.Storage = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(try context.identity())
    }

    func testLostWriteReplyRecoversOriginalIdentityAcrossReopen() throws {
        let storage = MemoryStorage()
        let context = IdentityContext(secureStorage: storage)
        let prepared = try context.prepareIdentityCreation()
        try context.reserveOperation(id: prepared.operationId)
        storage.loseNextSaveReply = true
        XCTAssertThrowsError(try context.finalizeOperation(id: prepared.operationId)) { error in
            guard case RoostError.Storage = error else { return XCTFail("\(error)") }
        }
        let reopened = IdentityContext(secureStorage: storage)
        try reopened.finalizeOperation(id: prepared.operationId)
        XCTAssertEqual(try reopened.identity(), prepared.identity)
        XCTAssertTrue(try reopened.unfinishedOperations().isEmpty)
    }
}
