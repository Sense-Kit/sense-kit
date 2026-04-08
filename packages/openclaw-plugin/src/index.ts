export type SenseKitPlaceSharingMode = "labels_only" | "precise_coordinates";

export type SenseKitSignalCollector =
  | "motion"
  | "location"
  | "power"
  | "health"
  | "manual"
  | "unknown";

export type SenseKitSignalPolarity = "support" | "oppose";

export interface SenseKitDeviceInfo {
  device_id: string;
  platform: string;
  place_sharing_mode: SenseKitPlaceSharingMode;
}

export interface SenseKitContextSignal {
  schema_version: string;
  signal_id: string;
  signal_key: string;
  collector?: SenseKitSignalCollector;
  source: string;
  weight: number;
  polarity: SenseKitSignalPolarity;
  observed_at: string;
  received_at?: string;
  valid_for_sec: number;
  payload: Record<string, unknown>;
}

export interface SenseKitSignalBatch {
  schema_version: string;
  batch_id: string;
  sent_at: string;
  device: SenseKitDeviceInfo;
  signals: SenseKitContextSignal[];
  delivery: {
    attempt: number;
    queued_at: string;
  };
}

export interface SenseKitTrustedAction {
  action_type: string;
  batch_id: string;
  device_id: string;
  created_at: string;
  signal_keys: string[];
  target_channel?: string;
  target_recipient?: string;
  policy_tags?: string[];
  metadata?: Record<string, unknown>;
}

export interface SenseKitStatusSnapshot {
  device_id: string;
  updated_at: string;
  last_batch_id: string;
  signal_keys: string[];
}

export interface BuildTrustedActionOptions {
  action_type: string;
  created_at: string;
  target_channel?: string;
  target_recipient?: string;
  policy_tags?: string[];
  metadata?: Record<string, unknown>;
}

export function buildSenseKitSessionKey(batchId: string): string {
  return `hook:sensekit:${batchId}`;
}

export function extractSignalKeys(batch: Pick<SenseKitSignalBatch, "signals">): string[] {
  return [...new Set(batch.signals.map((signal) => signal.signal_key))];
}

export function summarizeSenseKitBatch(batch: SenseKitSignalBatch): string {
  const signalKeys = extractSignalKeys(batch);
  const signalLabel = batch.signals.length === 1 ? "signal" : "signals";
  const keysSummary = signalKeys.length === 0 ? "no signal keys" : signalKeys.join(", ");

  return `SenseKit batch ${batch.batch_id} from ${batch.device.platform} (${batch.device.place_sharing_mode}) with ${batch.signals.length} ${signalLabel}: ${keysSummary}`;
}

export function buildTrustedAction(
  batch: SenseKitSignalBatch,
  options: BuildTrustedActionOptions
): SenseKitTrustedAction {
  return {
    action_type: options.action_type,
    batch_id: batch.batch_id,
    device_id: batch.device.device_id,
    created_at: options.created_at,
    signal_keys: extractSignalKeys(batch),
    target_channel: options.target_channel,
    target_recipient: options.target_recipient,
    policy_tags: options.policy_tags,
    metadata: options.metadata
  };
}

export function formatSenseKitStatus(snapshot: SenseKitStatusSnapshot): string {
  const keysSummary =
    snapshot.signal_keys.length === 0 ? "no signals" : snapshot.signal_keys.join(", ");

  return `SenseKit ${snapshot.device_id} last batch ${snapshot.last_batch_id} at ${snapshot.updated_at} with ${keysSummary}`;
}
