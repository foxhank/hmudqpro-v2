import XCTest
@testable import hmudqpro

/// KeychainStore 单测。跑在模拟器上（Keychain 在主机测试环境不可用）。
final class KeychainStoreTests: XCTestCase {
    private let testKey = "test.keychain.\(UUID().uuidString)"

    override func tearDown() {
        KeychainStore.remove(forKey: testKey)
        super.tearDown()
    }

    func testSetGetString() throws {
        try KeychainStore.setString("Hmudq@233617", forKey: testKey)
        XCTAssertEqual(KeychainStore.string(forKey: testKey), "Hmudq@233617")
    }

    func testUpdateOverwrites() throws {
        try KeychainStore.setString("old", forKey: testKey)
        try KeychainStore.setString("new", forKey: testKey)
        XCTAssertEqual(KeychainStore.string(forKey: testKey), "new")
    }

    func testMissingReturnsNil() {
        XCTAssertNil(KeychainStore.string(forKey: "test.keychain.nonexistent"))
    }

    func testRemove() throws {
        try KeychainStore.setString("x", forKey: testKey)
        KeychainStore.remove(forKey: testKey)
        XCTAssertNil(KeychainStore.string(forKey: testKey))
    }

    func testChineseString() throws {
        try KeychainStore.setString("百湖医大", forKey: testKey)
        XCTAssertEqual(KeychainStore.string(forKey: testKey), "百湖医大")
    }

    func testClearCredentials() throws {
        try KeychainStore.setString("2316820123", forKey: KeychainStore.Keys.studentID)
        try KeychainStore.setString("pw", forKey: KeychainStore.Keys.password)
        KeychainStore.clearCredentials()
        XCTAssertNil(KeychainStore.string(forKey: KeychainStore.Keys.studentID))
        XCTAssertNil(KeychainStore.string(forKey: KeychainStore.Keys.password))
    }
}
