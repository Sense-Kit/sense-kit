import test from "node:test";
import assert from "node:assert/strict";
import {
  buildSenseKitSessionKey,
  buildTrustedAction,
  formatSenseKitStatus,
  summarizeSenseKitBatch
} from "../dist/index.js";

const batch = {
  schema_version: "sensekit.signal_batch.v1",
  batch_id: "batch_01",
  sent_at: "2026-04-08T08:15:00Z",
  device: {
    device_id: "iphone_julian",
    platform: "ios",
    place_sharing_mode: "labels_only"
  },
  signals: [
    {
      schema_version: "sensekit.context_signal.v1",
      signal_id: "sig_motion_01",
      signal_key: "motion.activity_observed",
      collector: "motion",
      source: "coremotion_activity",
      weight: 1,
      polarity: "support",
      observed_at: "2026-04-08T08:14:55Z",
      received_at: "2026-04-08T08:14:55Z",
      valid_for_sec: 1,
      payload: {
        primary_kind: "walking"
      }
    },
    {
      schema_version: "sensekit.context_signal.v1",
      signal_id: "sig_power_01",
      signal_key: "power.battery_state_changed",
      collector: "power",
      source: "uidevice_battery",
      weight: 1,
      polarity: "support",
      observed_at: "2026-04-08T08:15:00Z",
      received_at: "2026-04-08T08:15:00Z",
      valid_for_sec: 120,
      payload: {
        current_state: "unplugged"
      }
    }
  ],
  delivery: {
    attempt: 1,
    queued_at: "2026-04-08T08:15:00Z"
  }
};

test("builds a session key from the raw batch id", () => {
  assert.equal(buildSenseKitSessionKey(batch.batch_id), "hook:sensekit:batch_01");
});

test("summarizes a raw signal batch", () => {
  assert.match(summarizeSenseKitBatch(batch), /batch_01/);
  assert.match(summarizeSenseKitBatch(batch), /motion\.activity_observed/);
  assert.match(summarizeSenseKitBatch(batch), /power\.battery_state_changed/);
});

test("builds a trusted action record from a batch", () => {
  assert.deepEqual(
    buildTrustedAction(batch, {
      action_type: "morning_handoff_ready",
      created_at: "2026-04-08T08:16:00Z",
      target_channel: "telegram",
      policy_tags: ["brief"]
    }),
    {
      action_type: "morning_handoff_ready",
      batch_id: "batch_01",
      device_id: "iphone_julian",
      created_at: "2026-04-08T08:16:00Z",
      signal_keys: ["motion.activity_observed", "power.battery_state_changed"],
      target_channel: "telegram",
      target_recipient: undefined,
      policy_tags: ["brief"],
      metadata: undefined
    }
  );
});

test("formats status line", () => {
  assert.match(
    formatSenseKitStatus({
      device_id: "iphone_julian",
      updated_at: "2026-04-08T08:15:00Z",
      last_batch_id: "batch_01",
      signal_keys: ["motion.activity_observed", "power.battery_state_changed"]
    }),
    /batch_01/
  );
});
