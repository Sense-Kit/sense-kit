import Foundation
import XCTest
@testable import SenseKitRuntime

final class SnapshotEnricherTests: XCTestCase {
    func testBuildSnapshotIncludesHealthSnapshotFromProvider() async {
        let capturedAt = date(hour: 7, minute: 5)
        let snapshot = ContextSnapshot(
            capturedAt: capturedAt,
            routine: .init(awake: true, focus: nil, workout: .inactive),
            place: .init(type: .home, freshness: .recent),
            calendar: .init(inMeeting: false, nextMeetingInMin: 20, freshness: .recent),
            device: .init(batteryPercentBucket: 70, charging: true)
        )
        let health = HealthSnapshot(
            capturedAt: capturedAt,
            sleep: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                lastSleepStartAt: date(hour: 22, minute: 40, day: 6),
                lastSleepEndAt: date(hour: 6, minute: 30),
                asleepMinutes: 470,
                inBedMinutes: 495,
                sevenDayAvgAsleepMinutes: 455,
                deltaVsSevenDayAvgMinutes: 15
            ),
            workout: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                active: false,
                todayCount: 1,
                todayTotalMinutes: 48,
                todayActiveEnergyKcal: 320,
                lastType: "traditional_strength_training",
                lastStartAt: date(hour: 9, minute: 15),
                lastEndAt: date(hour: 10, minute: 3)
            ),
            nutrition: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                lastLoggedAt: date(hour: 12, minute: 10),
                proteinG: 118,
                proteinTargetG: 160,
                proteinRemainingG: 42,
                caloriesKcal: 2_110,
                caloriesTargetKcal: 2_700,
                caloriesRemainingKcal: 590,
                waterML: 1_650,
                waterTargetML: 3_000,
                waterRemainingML: 1_350
            ),
            activity: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                steps: 7_420,
                activeEnergyKcal: 612,
                distanceKM: 5.8,
                sevenDayAvgStepsByNow: 9_100,
                deltaVsSevenDayAvgStepsByNow: -1_680
            ),
            recovery: .init(
                available: true,
                authorized: true,
                freshness: .recent,
                restingHeartRateBPM: 54,
                restingHeartRateDeltaVs14DayAvgBPM: 4,
                hrvSDNNMs: 39,
                hrvDeltaVs14DayAvgMs: -11,
                measuredAt: date(hour: 5, minute: 40)
            ),
            mind: .init(
                available: true,
                authorized: false,
                freshness: .stale,
                latestState: nil,
                loggedAt: nil
            )
        )
        let enricher = SnapshotEnricher(
            provider: StubSnapshotProvider(snapshot: snapshot),
            healthProvider: StubHealthSnapshotProvider(health: health)
        )

        let result = await enricher.buildSnapshot(at: capturedAt, state: RuntimeState())

        XCTAssertEqual(result.health, health)
        XCTAssertEqual(result.health.nutrition.proteinRemainingG, 42)
        XCTAssertEqual(result.health.recovery.hrvDeltaVs14DayAvgMs, -11)
    }

    func testBuildSnapshotFallsBackToEmptyHealthSnapshot() async {
        let capturedAt = date(hour: 7, minute: 5)
        let enricher = SnapshotEnricher(provider: DefaultSnapshotProvider())

        let result = await enricher.buildSnapshot(at: capturedAt, state: RuntimeState())

        XCTAssertEqual(result.health, .empty(capturedAt: capturedAt))
    }

    private func date(hour: Int, minute: Int, day: Int = 7) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: day, hour: hour, minute: minute))!
    }
}

private struct StubSnapshotProvider: SnapshotProvider {
    let snapshot: ContextSnapshot

    func currentSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot {
        snapshot
    }
}

private struct StubHealthSnapshotProvider: HealthSnapshotProviding {
    let health: HealthSnapshot

    func currentHealthSnapshot(at date: Date, state: RuntimeState) async -> HealthSnapshot {
        health
    }
}
