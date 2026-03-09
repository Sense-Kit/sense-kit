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
    type: "home" | "work" | "other";
    freshness: "live" | "recent" | "stale";
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

