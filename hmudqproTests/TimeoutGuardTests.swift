import XCTest
@testable import hmudqpro

final class TimeoutGuardTests: XCTestCase {
    func testFastOperationCompletes() async throws {
        let result = try await TimeoutGuard.withTimeout(seconds: 2) { () -> Int in
            try await Task.sleep(nanoseconds: 50_000_000)
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    func testHangingOperationTimesOut() async {
        do {
            _ = try await TimeoutGuard.withTimeout(seconds: 1) { () -> Int in
                // 模拟教务卡死：永不返回
                while true {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            XCTFail("应超时抛错")
        } catch let TimeoutGuard.TimeoutError.timedOut(seconds) {
            XCTAssertEqual(seconds, 1)
        } catch {
            XCTFail("错误类型不对: \(error)")
        }
    }

    func testOperationErrorPropagates() async {
        struct Boom: Error {}
        do {
            _ = try await TimeoutGuard.withTimeout(seconds: 2) { () -> Int in throw Boom() }
            XCTFail("应抛出原始错误")
        } catch is Boom {
            // 正确：操作自身的错误原样传递，不被超时吞掉
        } catch {
            XCTFail("错误类型不对: \(error)")
        }
    }

    func testCancellationDetection() {
        XCTAssertTrue(ScheduleViewModel.isCancellation(CancellationError()))
        XCTAssertTrue(ScheduleViewModel.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(ScheduleViewModel.isCancellation(URLError(.timedOut)))
        XCTAssertFalse(ScheduleViewModel.isCancellation(
            APIClient.APIError.http(status: 500, url: "https://x", body: nil)))
    }
}
