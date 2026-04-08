export type SignalPolarity = "support" | "oppose";
export type SignalCollector = "motion" | "location" | "power" | "health" | "manual" | "unknown";

export interface ContextSignal {
  schema_version: "sensekit.context_signal.v1";
  signal_id: string;
  signal_key: string;
  collector?: SignalCollector;
  source: string;
  weight: number;
  polarity: SignalPolarity;
  observed_at: string;
  received_at?: string;
  valid_for_sec: number;
  payload: Record<string, unknown>;
}

export interface SignalBatchDevice {
  device_id: string;
  platform: string;
  place_sharing_mode: "labels_only" | "precise_coordinates";
}

export interface SenseKitSignalBatch {
  schema_version: "sensekit.signal_batch.v1";
  batch_id: string;
  sent_at: string;
  device: SignalBatchDevice;
  signals: ContextSignal[];
  delivery: {
    attempt: number;
    queued_at: string;
  };
}
