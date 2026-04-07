export type SignalPolarity = "support" | "oppose";

export interface ContextSignal {
  schema_version: "sensekit.context_signal.v1";
  signal_id: string;
  signal_key: string;
  source: string;
  weight: number;
  polarity: SignalPolarity;
  observed_at: string;
  valid_for_sec: number;
  payload: Record<string, unknown>;
}

export interface ContextEvent {
  schema_version: "sensekit.context_event.v1";
  event_id: string;
  event_type: string;
  occurred_at: string;
  confidence: number;
  reasons: string[];
  mode_hint: string;
  cooldown_sec: number;
  dedupe_key: string;
}

export interface ContextSnapshot {
  schema_version: "sensekit.context_snapshot.v1";
  captured_at: string;
  routine: {
    awake: boolean;
    focus: string | null;
    workout: "inactive" | "active";
  };
  place: {
    type: "home" | "work" | "custom" | "other";
    identifier?: string | null;
    name?: string | null;
    freshness: "live" | "recent" | "stale";
    coordinate?: {
      latitude: number;
      longitude: number;
    } | null;
  };
  calendar: {
    in_meeting: boolean;
    next_meeting_in_min: number | null;
    freshness: "live" | "recent" | "stale";
  };
  device: {
    battery_percent_bucket: number;
    charging: boolean;
  };
  health: {
    captured_at: string;
    sleep: HealthSleepSnapshot;
    workout: HealthWorkoutSnapshot;
    nutrition: HealthNutritionSnapshot;
    activity: HealthActivitySnapshot;
    recovery: HealthRecoverySnapshot;
    mind: HealthMindSnapshot;
  };
}

export interface HealthSleepSnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  last_sleep_start_at: string | null;
  last_sleep_end_at: string | null;
  asleep_minutes: number | null;
  in_bed_minutes: number | null;
  seven_day_avg_asleep_minutes: number | null;
  delta_vs_seven_day_avg_minutes: number | null;
}

export interface HealthWorkoutSnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  active: boolean;
  today_count: number | null;
  today_total_minutes: number | null;
  today_active_energy_kcal: number | null;
  last_type: string | null;
  last_start_at: string | null;
  last_end_at: string | null;
}

export interface HealthNutritionSnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  last_logged_at: string | null;
  protein_g: number | null;
  protein_target_g: number | null;
  protein_remaining_g: number | null;
  calories_kcal: number | null;
  calories_target_kcal: number | null;
  calories_remaining_kcal: number | null;
  water_ml: number | null;
  water_target_ml: number | null;
  water_remaining_ml: number | null;
}

export interface HealthActivitySnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  steps: number | null;
  active_energy_kcal: number | null;
  distance_km: number | null;
  seven_day_avg_steps_by_now: number | null;
  delta_vs_seven_day_avg_steps_by_now: number | null;
}

export interface HealthRecoverySnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  resting_heart_rate_bpm: number | null;
  resting_heart_rate_delta_vs_14_day_avg_bpm: number | null;
  hrv_sdnn_ms: number | null;
  hrv_delta_vs_14_day_avg_ms: number | null;
  measured_at: string | null;
}

export interface HealthMindSnapshot {
  available: boolean;
  authorized: boolean;
  freshness: "live" | "recent" | "stale";
  latest_state: string | null;
  logged_at: string | null;
}

export interface PolicyDecision {
  schema_version: "sensekit.policy_decision.v1";
  event_type: string;
  allowed_actions: string[];
  blocked_actions: string[];
  delivery_channel_preference: string[];
  ttl_sec: number;
}

export interface SenseKitEventEnvelope {
  schema_version: "sensekit.event.v1";
  device_id: string;
  event: ContextEvent;
  snapshot: ContextSnapshot;
  policy: PolicyDecision;
  delivery: {
    attempt: number;
    queued_at: string;
  };
}
