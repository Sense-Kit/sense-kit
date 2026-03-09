import test from "node:test";
import assert from "node:assert/strict";
import { formatSenseKitStatus } from "../dist/index.js";

test("formats status line", () => {
  assert.match(
    formatSenseKitStatus({
      device_id: "iphone_julian",
      updated_at: "2026-03-09T07:44:11Z",
      last_event_type: "driving_started"
    }),
    /driving_started/
  );
});

