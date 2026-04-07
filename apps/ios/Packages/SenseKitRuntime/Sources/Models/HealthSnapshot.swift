import Foundation

public struct HealthSnapshot: Codable, Equatable, Sendable {
    public struct Sleep: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let lastSleepStartAt: Date?
        public let lastSleepEndAt: Date?
        public let asleepMinutes: Int?
        public let inBedMinutes: Int?
        public let sevenDayAvgAsleepMinutes: Int?
        public let deltaVsSevenDayAvgMinutes: Int?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            lastSleepStartAt: Date? = nil,
            lastSleepEndAt: Date? = nil,
            asleepMinutes: Int? = nil,
            inBedMinutes: Int? = nil,
            sevenDayAvgAsleepMinutes: Int? = nil,
            deltaVsSevenDayAvgMinutes: Int? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.lastSleepStartAt = lastSleepStartAt
            self.lastSleepEndAt = lastSleepEndAt
            self.asleepMinutes = asleepMinutes
            self.inBedMinutes = inBedMinutes
            self.sevenDayAvgAsleepMinutes = sevenDayAvgAsleepMinutes
            self.deltaVsSevenDayAvgMinutes = deltaVsSevenDayAvgMinutes
        }

        public static var unavailable: Sleep {
            Sleep(available: false, authorized: false, freshness: .stale)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case lastSleepStartAt = "last_sleep_start_at"
            case lastSleepEndAt = "last_sleep_end_at"
            case asleepMinutes = "asleep_minutes"
            case inBedMinutes = "in_bed_minutes"
            case sevenDayAvgAsleepMinutes = "seven_day_avg_asleep_minutes"
            case deltaVsSevenDayAvgMinutes = "delta_vs_seven_day_avg_minutes"
        }
    }

    public struct Workout: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let active: Bool
        public let todayCount: Int?
        public let todayTotalMinutes: Int?
        public let todayActiveEnergyKcal: Int?
        public let lastType: String?
        public let lastStartAt: Date?
        public let lastEndAt: Date?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            active: Bool,
            todayCount: Int? = nil,
            todayTotalMinutes: Int? = nil,
            todayActiveEnergyKcal: Int? = nil,
            lastType: String? = nil,
            lastStartAt: Date? = nil,
            lastEndAt: Date? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.active = active
            self.todayCount = todayCount
            self.todayTotalMinutes = todayTotalMinutes
            self.todayActiveEnergyKcal = todayActiveEnergyKcal
            self.lastType = lastType
            self.lastStartAt = lastStartAt
            self.lastEndAt = lastEndAt
        }

        public static var unavailable: Workout {
            Workout(available: false, authorized: false, freshness: .stale, active: false)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case active
            case todayCount = "today_count"
            case todayTotalMinutes = "today_total_minutes"
            case todayActiveEnergyKcal = "today_active_energy_kcal"
            case lastType = "last_type"
            case lastStartAt = "last_start_at"
            case lastEndAt = "last_end_at"
        }
    }

    public struct Nutrition: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let lastLoggedAt: Date?
        public let proteinG: Int?
        public let proteinTargetG: Int?
        public let proteinRemainingG: Int?
        public let caloriesKcal: Int?
        public let caloriesTargetKcal: Int?
        public let caloriesRemainingKcal: Int?
        public let waterML: Int?
        public let waterTargetML: Int?
        public let waterRemainingML: Int?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            lastLoggedAt: Date? = nil,
            proteinG: Int? = nil,
            proteinTargetG: Int? = nil,
            proteinRemainingG: Int? = nil,
            caloriesKcal: Int? = nil,
            caloriesTargetKcal: Int? = nil,
            caloriesRemainingKcal: Int? = nil,
            waterML: Int? = nil,
            waterTargetML: Int? = nil,
            waterRemainingML: Int? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.lastLoggedAt = lastLoggedAt
            self.proteinG = proteinG
            self.proteinTargetG = proteinTargetG
            self.proteinRemainingG = proteinRemainingG
            self.caloriesKcal = caloriesKcal
            self.caloriesTargetKcal = caloriesTargetKcal
            self.caloriesRemainingKcal = caloriesRemainingKcal
            self.waterML = waterML
            self.waterTargetML = waterTargetML
            self.waterRemainingML = waterRemainingML
        }

        public static var unavailable: Nutrition {
            Nutrition(available: false, authorized: false, freshness: .stale)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case lastLoggedAt = "last_logged_at"
            case proteinG = "protein_g"
            case proteinTargetG = "protein_target_g"
            case proteinRemainingG = "protein_remaining_g"
            case caloriesKcal = "calories_kcal"
            case caloriesTargetKcal = "calories_target_kcal"
            case caloriesRemainingKcal = "calories_remaining_kcal"
            case waterML = "water_ml"
            case waterTargetML = "water_target_ml"
            case waterRemainingML = "water_remaining_ml"
        }
    }

    public struct Activity: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let steps: Int?
        public let activeEnergyKcal: Int?
        public let distanceKM: Double?
        public let sevenDayAvgStepsByNow: Int?
        public let deltaVsSevenDayAvgStepsByNow: Int?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            steps: Int? = nil,
            activeEnergyKcal: Int? = nil,
            distanceKM: Double? = nil,
            sevenDayAvgStepsByNow: Int? = nil,
            deltaVsSevenDayAvgStepsByNow: Int? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.steps = steps
            self.activeEnergyKcal = activeEnergyKcal
            self.distanceKM = distanceKM
            self.sevenDayAvgStepsByNow = sevenDayAvgStepsByNow
            self.deltaVsSevenDayAvgStepsByNow = deltaVsSevenDayAvgStepsByNow
        }

        public static var unavailable: Activity {
            Activity(available: false, authorized: false, freshness: .stale)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case steps
            case activeEnergyKcal = "active_energy_kcal"
            case distanceKM = "distance_km"
            case sevenDayAvgStepsByNow = "seven_day_avg_steps_by_now"
            case deltaVsSevenDayAvgStepsByNow = "delta_vs_seven_day_avg_steps_by_now"
        }
    }

    public struct Recovery: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let restingHeartRateBPM: Int?
        public let restingHeartRateDeltaVs14DayAvgBPM: Int?
        public let hrvSDNNMs: Int?
        public let hrvDeltaVs14DayAvgMs: Int?
        public let measuredAt: Date?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            restingHeartRateBPM: Int? = nil,
            restingHeartRateDeltaVs14DayAvgBPM: Int? = nil,
            hrvSDNNMs: Int? = nil,
            hrvDeltaVs14DayAvgMs: Int? = nil,
            measuredAt: Date? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.restingHeartRateBPM = restingHeartRateBPM
            self.restingHeartRateDeltaVs14DayAvgBPM = restingHeartRateDeltaVs14DayAvgBPM
            self.hrvSDNNMs = hrvSDNNMs
            self.hrvDeltaVs14DayAvgMs = hrvDeltaVs14DayAvgMs
            self.measuredAt = measuredAt
        }

        public static var unavailable: Recovery {
            Recovery(available: false, authorized: false, freshness: .stale)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case restingHeartRateBPM = "resting_heart_rate_bpm"
            case restingHeartRateDeltaVs14DayAvgBPM = "resting_heart_rate_delta_vs_14_day_avg_bpm"
            case hrvSDNNMs = "hrv_sdnn_ms"
            case hrvDeltaVs14DayAvgMs = "hrv_delta_vs_14_day_avg_ms"
            case measuredAt = "measured_at"
        }
    }

    public struct Mind: Codable, Equatable, Sendable {
        public let available: Bool
        public let authorized: Bool
        public let freshness: SnapshotFreshness
        public let latestState: String?
        public let loggedAt: Date?

        public init(
            available: Bool,
            authorized: Bool,
            freshness: SnapshotFreshness,
            latestState: String? = nil,
            loggedAt: Date? = nil
        ) {
            self.available = available
            self.authorized = authorized
            self.freshness = freshness
            self.latestState = latestState
            self.loggedAt = loggedAt
        }

        public static var unavailable: Mind {
            Mind(available: false, authorized: false, freshness: .stale)
        }

        enum CodingKeys: String, CodingKey {
            case available
            case authorized
            case freshness
            case latestState = "latest_state"
            case loggedAt = "logged_at"
        }
    }

    public let capturedAt: Date
    public let sleep: Sleep
    public let workout: Workout
    public let nutrition: Nutrition
    public let activity: Activity
    public let recovery: Recovery
    public let mind: Mind

    public init(
        capturedAt: Date,
        sleep: Sleep,
        workout: Workout,
        nutrition: Nutrition,
        activity: Activity,
        recovery: Recovery,
        mind: Mind
    ) {
        self.capturedAt = capturedAt
        self.sleep = sleep
        self.workout = workout
        self.nutrition = nutrition
        self.activity = activity
        self.recovery = recovery
        self.mind = mind
    }

    public static func empty(capturedAt: Date) -> HealthSnapshot {
        HealthSnapshot(
            capturedAt: capturedAt,
            sleep: .unavailable,
            workout: .unavailable,
            nutrition: .unavailable,
            activity: .unavailable,
            recovery: .unavailable,
            mind: .unavailable
        )
    }

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case sleep
        case workout
        case nutrition
        case activity
        case recovery
        case mind
    }
}
