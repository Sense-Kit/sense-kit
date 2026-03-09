import XCTest
@testable import SenseKitUI

final class SenseKitUITests: XCTestCase {
    func testPreviewModelStartsWithConnectionStatus() {
        XCTAssertFalse(SenseKitAppModel.preview.connectionStatus.isEmpty)
    }
}
