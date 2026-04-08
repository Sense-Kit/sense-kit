import Foundation
import XCTest
@testable import SenseKitRuntime

final class SignalBatchEncodingTests: XCTestCase {
    func testSignalBatchEncodesStableSnakeCaseJson() throws {
        let observedAt = Date(timeIntervalSince1970: 1_775_606_400)
        let signal = ContextSignal(
            signalID: "sig-1",
            signalKey: "motion.activity_observed",
            collector: .motion,
            source: "coremotion_activity",
            weight: 1.0,
            polarity: .support,
            observedAt: observedAt,
            receivedAt: observedAt,
            validForSec: 1,
            payload: [
                "primary_kind": .string("walking"),
                "confidence": .string("high"),
                "walking": .bool(true)
            ]
        )
        let batch = SenseKitSignalBatch(
            batchID: "batch-1",
            sentAt: observedAt,
            device: SignalBatchDevice(
                deviceID: "device-1",
                placeSharingMode: .labelsOnly
            ),
            signals: [signal],
            delivery: DeliveryMetadata(attempt: 1, queuedAt: observedAt)
        )

        let data = try JSONCoding.encoder.encode(batch)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let device = try XCTUnwrap(jsonObject["device"] as? [String: Any])
        let signals = try XCTUnwrap(jsonObject["signals"] as? [[String: Any]])
        let firstSignal = try XCTUnwrap(signals.first)
        let delivery = try XCTUnwrap(jsonObject["delivery"] as? [String: Any])

        XCTAssertEqual(jsonObject["schema_version"] as? String, "sensekit.signal_batch.v1")
        XCTAssertEqual(jsonObject["batch_id"] as? String, "batch-1")
        XCTAssertEqual(device["device_id"] as? String, "device-1")
        XCTAssertEqual(device["place_sharing_mode"] as? String, "labels_only")
        XCTAssertEqual(firstSignal["collector"] as? String, "motion")
        XCTAssertEqual(firstSignal["signal_key"] as? String, "motion.activity_observed")
        XCTAssertEqual(delivery["attempt"] as? Int, 1)
    }
}
