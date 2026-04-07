# SenseKit v3 — Context Runtime for AI Agents

**Status:** Draft v3
**Date:** 2026-03-09
**Owner:** codecoast labs
**Positioning:** OpenClaw-first, local-first, event-first, passive-first

> **One-line thesis**
> SenseKit turns real-world state changes into stable, policy-aware events that change how AI agents behave — and it works the moment you open the app.

---

## 0. What changed from v2

### The problem with v2
v2 was architecturally correct but made one fatal UX mistake: it required users to manually configure Shortcuts personal automations before the product did anything. That's 15–20 minutes of fiddly iOS configuration before the first "wow" moment. Most users would never finish setup.

### The v3 rule
**The app must work on download + permission approvals alone. Zero Shortcuts. Zero terminal commands. Under 3 minutes to first useful event.**

Shortcuts become an optional precision boost for power users, not the foundation.

### What changed

| v2 | v3 |
|----|-----|
| Shortcuts = Tier A (required) | Passive sensors = Tier A (required) |
| Sensors = Tier B (corroboration only) | Shortcuts = Tier B (optional precision boost) |
| Setup requires Shortcuts automation creation | Setup requires only permission approvals + one-tap config |
| "Don't do passive wake detection" | "Do passive wake detection with multi-signal corroboration" |
| Users must understand Shortcuts | Users must only tap toggles |

### What stayed the same
- Context runtime, not behavioral data platform
- Event-first (ContextSignal → ContextEvent → ContextSnapshot → PolicyDecision)
- OpenClaw webhook/hook integration as primary delivery
- Local-first, explicit consent, auditability
- No x402 marketplace
- No phone-as-server
- No fake stress/energy scores
- Deterministic event engine (LLM never decides if an event happened)

---

## 1. The UX contract

### Download → Value in under 3 minutes

```
1. Download app, open it                              [0:00]
2. "What should your AI adapt to?"
   → Toggle: Wake Brief                               [0:15]
   → Toggle: Driving Mode
   → Toggle: Home/Work
   → Toggle: Workout Follow-up
3. Permission approvals (only for enabled features):
   → Motion & Fitness (wake + driving)                 [0:30]
   → Location (home/work)
   → Bluetooth (driving — shows car picker)
   → HealthKit (workout)
4. Quick config (only if relevant):
   → "Pick your car" → list of paired BT devices       [1:00]
   → "Where's home?" → map with pin → confirm
   → "Where's work?" → map with pin → confirm
5. Connect to OpenClaw:
   → Paste Gateway URL + token, OR                     [2:00]
   → Scan QR code from Gateway terminal
6. Done. Events start flowing immediately.              [2:30]
```

No Shortcuts. No terminal commands. No YAML editing.

### The "Boost Precision" optional tier

After the core experience works passively, the Settings screen offers:

> "Want even more precise wake detection? Add this Shortcut for your alarm."

Each boost shows: what it improves, a "Install Shortcut" button that deep-links into Shortcuts with a pre-configured template (the user still has to confirm, but the template is ready), and the confidence improvement it provides.

This is an optional power-user enhancement. The product works without it.

---

## 2. Detection architecture: passive-first with corroboration

### Design principle
No single sensor is reliable enough alone. But 2–3 corroborating signals together are highly reliable. The event engine uses a **weighted corroboration model**: each signal contributes a confidence score, and the event fires when the combined score crosses a threshold.

### 2.1 `wake_confirmed`

**Passive signals (all available without Shortcuts):**

| Signal | API | Background? | Confidence weight |
|--------|-----|-------------|-------------------|
| Phone pickup after long stationary period | CoreMotion (flat→raised transition) | Yes — coprocessor | 0.35 |
| Activity changes from stationary to walking | CMMotionActivityManager | Yes — coprocessor | 0.25 |
| Charger disconnect in morning window | UIDevice batteryState notification | Yes — observer | 0.20 |
| Time within configured wake window (e.g. 5–10 AM) | Clock | N/A | 0.10 |
| No wake_confirmed in last 12 hours | Event engine state | N/A | 0.10 |

**Threshold:** Fire when combined score ≥ 0.70

**Example — typical morning:**
```
06:47  Charger disconnected (+0.20)
06:47  Phone picked up after 7h stationary (+0.35)
06:48  Activity: stationary → walking (+0.25)
06:48  Time is in 5–10 AM window (+0.10)
06:48  No wake in last 12h (+0.10)
       Total: 1.00 → FIRE wake_confirmed (confidence: 0.98)
```

**Example — midnight bathroom trip (should NOT fire):**
```
02:15  Phone picked up (+0.35)
02:15  Time is NOT in 5–10 AM window (+0.00)
02:15  Activity still stationary (+0.00)
02:15  Charger still connected (+0.00)
       Total: 0.35 → BELOW THRESHOLD, no event
```

**Optional Shortcuts boost:**
If user adds an alarm/sleep Shortcuts automation, it contributes +0.50 confidence weight and fires immediately without needing corroboration. This makes wake detection instant and near-certain.

**Cooldown:** 12 hours. One wake event per day.

---

### 2.2 `driving_started` / `driving_stopped`

**Passive signals:**

| Signal | API | Background? | Confidence weight |
|--------|-----|-------------|-------------------|
| CMMotionActivity reports .automotive | CMMotionActivityManager | Yes — coprocessor | 0.40 |
| Configured car Bluetooth device connected | CoreBluetooth (state restoration) | Yes — BLE background | 0.45 |
| Significant location change while automotive | CLLocationManager (significant change) | Yes — relaunches app | 0.15 |

**Threshold:** Fire when combined score ≥ 0.60

**With car Bluetooth configured (one-tap during onboarding):**
```
07:41  Car Bluetooth "Julian Car" connected (+0.45)
07:41  CMMotionActivity: .automotive (+0.40)
       Total: 0.85 → FIRE driving_started (confidence: 0.92)
```

**Without car Bluetooth (still works, lower confidence):**
```
07:41  CMMotionActivity: .automotive (+0.40)
07:43  Significant location change while automotive (+0.15)
       Total: 0.55 → BELOW THRESHOLD... wait
07:45  CMMotionActivity still .automotive for 4+ min (+0.15 duration bonus)
       Total: 0.70 → FIRE driving_started (confidence: 0.78)
```

**`driving_stopped` detection:**
```
Car Bluetooth disconnected → immediate fire (high confidence)
OR: CMMotionActivity leaves .automotive for >3 minutes → fire with cooldown check
```

**Cooldown:** 15 minutes between `driving_started` events. Prevents flapping from traffic lights, parking, etc.

---

### 2.3 `arrived_home` / `left_home` / `arrived_work` / `left_work`

**Setup:** During onboarding, user taps "Set home" → current location or drop pin. Same for work. One tap each.

**Detection:** `CLLocationManager.startMonitoring(for: CLCircularRegion)` — one of the most reliable background mechanisms on iOS. The system wakes the app on region entry/exit even if it was terminated.

| Signal | API | Background? | Confidence |
|--------|-----|-------------|------------|
| Region entry/exit | CLCircularRegion monitoring | Yes — relaunches app | 0.90 |
| WiFi SSID match (if configured) | NEHotspotHelper or CaptiveNetwork | Foreground check | +0.10 boost |

**Cooldown:** 10 minutes between same-region events.

No Shortcuts needed. This is pure CoreLocation.

---

### 2.4 `workout_started` / `workout_ended`

**Passive signals:**

| Signal | API | Background? | Confidence |
|--------|-----|-------------|------------|
| HealthKit workout sample written | HKObserverQuery + background delivery | Yes — but delivery may be delayed | 0.85 |
| CMMotionActivity reports sustained .running or high activity | CMMotionActivityManager | Yes — coprocessor | 0.30 |

**Primary path:** HealthKit observer query detects when Apple Watch writes a workout sample. This is passive — the user just starts a workout on their Watch as normal, no special action needed.

**Known limitation:** HealthKit background delivery can be delayed (minutes, sometimes longer). This is acceptable for workout events — a 2-minute delay on "workout ended → send follow-up" is fine.

**Optional Shortcuts boost:** Apple Watch Workout Shortcuts trigger fires instantly. Adds +0.50 confidence and eliminates delay.

**Cooldown:** 30 minutes.

---

### 2.5 `focus_on` / `focus_off`

**This is the one event that genuinely needs Shortcuts or an alternative approach.**

There is no public API to passively detect Focus mode changes. Options:

**Option A (v1):** Offer this only as a Shortcuts-boosted event. The app doesn't try to detect Focus passively. The settings screen says: "Want focus-aware behavior? Add this one Shortcut." This is honest and keeps the product's passive-first promise intact — Focus is a bonus, not a core feature.

**Option B (v1.1):** Infer "deep work mode" from corroborating signals: no phone pickup for 30+ min + work hours + work location. This isn't Focus mode detection — it's attention-state inference. Lower confidence, but doesn't require any setup.

**Recommendation:** Ship with Option A for v1. It's the one Shortcut worth configuring, and the instruction is simple: "When [Work Focus] turns on → Run SenseKit action." One automation, not five.

---

## 3. Event catalog (unchanged from v2, detection logic updated)

| Event | Priority | Detection path | Shortcuts needed? | Setup required |
|-------|----------|----------------|-------------------|----------------|
| `wake_confirmed` | P0 | Corroboration: pickup + activity + charger + time window | No (optional boost) | None — works on Motion permission |
| `driving_started` | P0 | CoreMotion .automotive + optional car BT | No | Optional: pick car BT device |
| `driving_stopped` | P0 | BT disconnect or activity leaves .automotive | No | None |
| `workout_started` | P1 | HealthKit observer query | No | Needs HealthKit permission |
| `workout_ended` | P1 | HealthKit observer query | No | Needs HealthKit permission |
| `arrived_home` | P1 | CLCircularRegion monitoring | No | Set home location (one tap) |
| `left_home` | P1 | CLCircularRegion monitoring | No | Same |
| `arrived_work` | P1 | CLCircularRegion monitoring | No | Set work location (one tap) |
| `left_work` | P1 | CLCircularRegion monitoring | No | Same |
| `focus_on` | P2 | Shortcuts only (no passive path) | Yes | One Shortcut automation |
| `focus_off` | P2 | Shortcuts only (no passive path) | Yes | One Shortcut automation |

**9 of 11 events work with zero Shortcuts configuration.**

---

## 4. Core data model (unchanged from v2)

### 4.1 ContextSignal
A raw or near-raw input.
```json
{
  "type": "motion.automotive_detected",
  "source": "coremotion_coprocessor",
  "value": { "confidence": "high" },
  "measured_at": "2026-03-08T07:41:15Z",
  "freshness": "live"
}
```

### 4.2 ContextEvent
A stable event after rules, corroboration, and cooldown.
```json
{
  "id": "evt_01HXXYZ123",
  "type": "driving_started",
  "occurred_at": "2026-03-08T07:41:22Z",
  "confidence": 0.92,
  "reasons": [
    "car_bluetooth_connected",
    "coremotion_automotive"
  ],
  "mode_hint": "voice_note",
  "cooldown_sec": 900,
  "snapshot": {
    "place": "other",
    "calendar": { "in_meeting": false, "next_meeting_in_min": 38 },
    "transport": { "mode": "driving" }
  }
}
```

### 4.3 ContextSnapshot
Minimal, freshness-aware state shipped with events.
```json
{
  "timestamp": "2026-03-08T07:41:22Z",
  "routine": { "awake": true, "focus": null, "workout": "inactive" },
  "place": { "type": "other", "freshness": "recent" },
  "calendar": { "in_meeting": false, "next_meeting_in_min": 38 },
  "device": { "battery": 78, "charging": false }
}
```

### 4.4 PolicyDecision
What the assistant is allowed and expected to do.
```json
{
  "event_type": "driving_started",
  "allowed_actions": ["send_voice_note", "send_tts", "defer_long_text"],
  "blocked_actions": ["send_long_readable_markdown"],
  "delivery_channel_preference": ["telegram_voice_note", "voice_call", "text_brief"],
  "ttl_sec": 1800
}
```

---

## 5. Architecture

### 5.1 System overview

```
PASSIVE SENSORS (always running, no user action)
├── CoreMotion coprocessor (activity, pickup, steps)
├── CoreBluetooth (car BT connection)
├── CoreLocation (region monitoring, significant change)
├── HealthKit observer (workout events)
├── UIDevice (battery, charging)
└── EventKit (calendar reads on demand)
         │
         ▼
┌─────────────────────────────────┐
│     SenseKit Event Engine       │
│  ┌───────────┐ ┌─────────────┐ │
│  │ Signal    │ │ Corroboration│ │
│  │ Ingestion │→│ + Cooldown   │ │
│  └───────────┘ └──────┬──────┘ │
│                       │        │
│  ┌────────────────────▼──────┐ │
│  │ Policy Engine             │ │
│  │ (modality hint, allowed   │ │
│  │  actions, delivery prefs) │ │
│  └────────────┬──────────────┘ │
│               │                │
│  ┌────────────▼──────────────┐ │
│  │ Snapshot Enrichment       │ │
│  │ (calendar, place, device) │ │
│  └────────────┬──────────────┘ │
└───────────────┼────────────────┘
                │
                ▼
    Signed ContextEvent + Snapshot
                │
                ▼
   ┌────────────────────────────┐
   │  Delivery Client           │
   │  (HTTPS POST with retry,   │
   │   offline queue, dedup)    │
   └────────────┬───────────────┘
                │
                ▼
   OpenClaw Gateway /hooks/sensekit
                │
                ▼
   Hook mapping → Agent behavior change

OPTIONAL BOOST LAYER (user-configured)
├── Shortcuts automations (focus, alarm precision)
├── App Intents (receive Shortcut triggers)
└── Future: BLE wearable, Watch companion
```

### 5.2 Why outbound-only

The phone pushes events to the Gateway. It does not accept inbound connections. This avoids the NWListener background death problem (dies after ~15 min), works whether the Gateway is on LAN or remote (via Tailscale/tunnel), and fits OpenClaw's existing webhook architecture.

### 5.3 Background execution strategy

| Mechanism | What it enables | Reliability |
|-----------|----------------|-------------|
| CoreMotion coprocessor | Activity type, pickup detection | `VERIFIED_BY_PLATFORM_DOCS` — runs 24/7 on dedicated chip |
| CoreLocation region monitoring | Home/work arrival/departure | `VERIFIED_BY_PLATFORM_DOCS` — relaunches terminated apps |
| CoreLocation significant change | Location context enrichment | `VERIFIED_BY_PLATFORM_DOCS` — relaunches terminated apps |
| CoreBluetooth state restoration | Car Bluetooth detection | `VERIFIED_BY_PLATFORM_DOCS` — relaunches on BLE events (unless user force-quit) |
| HealthKit background delivery | Workout start/end detection | `REQUIRES_BENCH_TEST` — reports of delays and charging-only delivery |
| BGAppRefreshTask | Periodic state maintenance | `REQUIRES_BENCH_TEST` — system-controlled timing |
| App Intents from Shortcuts | Focus mode, alarm precision boost | `VERIFIED_BY_PLATFORM_DOCS` — runs when automation fires |

**Critical constraint:** None of these mechanisms give the app continuous foreground-like execution. The app gets brief execution windows (seconds to a few minutes) when woken by an event. All work must complete quickly: read sensors, compute event, POST to Gateway, persist state, return to suspension.

---

## 6. OpenClaw integration (unchanged from v2)

### 6.1 Webhook payload
```json
POST /hooks/sensekit
Authorization: Bearer <token>

{
  "schema_version": "sensekit.event.v1",
  "device_id": "iphone_julian",
  "event": {
    "schema_version": "sensekit.context_event.v1",
    "event_id": "evt_01HXXYZ123",
    "event_type": "wake_confirmed",
    "occurred_at": "2026-03-08T06:47:05Z",
    "confidence": 0.98,
    "reasons": ["motion.walking_to_stationary"],
    "mode_hint": "text_brief"
  },
  "snapshot": {
    "schema_version": "sensekit.context_snapshot.v1",
    "captured_at": "2026-03-08T06:47:05Z",
    "routine": { "awake": true, "focus": null, "workout": "inactive" },
    "place": { "type": "home", "freshness": "recent" },
    "calendar": { "in_meeting": false, "next_meeting_in_min": 46 },
    "device": { "battery_percent_bucket": 80, "charging": false }
  }
}
```

### 6.2 Gateway config
```json5
{
  hooks: {
    enabled: true,
    token: "${OPENCLAW_HOOKS_TOKEN}",
    mappings: [
      {
        match: { path: "sensekit" },
        action: "agent",
        agentId: "main",
        wakeMode: "now",
        name: "SenseKit",
        sessionKey: "hook:sensekit:{{event.event_id}}",
        messageTemplate: "SenseKit event: {{event.event_type}}\nConfidence: {{event.confidence}}\nMode hint: {{event.mode_hint}}\nSnapshot: {{snapshot}}",
        deliver: false
      }
    ]
  }
}
```

### 6.3 Skill behavior
The OpenClaw skill teaches the agent:
- treat SenseKit events as high-signal system events
- use `mode_hint` as default delivery mode
- generate morning brief only on `wake_confirmed`
- prefer shorter outputs while driving
- defer non-urgent messages during focus
- ask smart follow-ups after workout end

### 6.4 v1.1 plugin
`@sensekit/openclaw` plugin adds:
- cached snapshot + recent event history
- tools: `sensekit.state.get`, `sensekit.events.recent`
- admin: `/sensekit status`

---

## 7. Onboarding UX

### 7.1 Screen flow

**Screen 1: Welcome**
"SenseKit makes your AI assistant aware of your real world."
[Get Started]

**Screen 2: Feature Picker**
Four toggle cards, each with an icon and one-line description:
- 🌅 Wake Brief — "Morning brief when you actually wake up"
- 🚗 Driving Mode — "Voice-safe responses while driving"
- 🏠 Home / Work — "Smart behavior when you arrive or leave"
- 💪 Workout — "Follow-up when your workout ends"

Each card shows the permissions it needs before the user enables it.

**Screen 3: Permissions** (only for enabled features)
Standard iOS permission dialogs fire in sequence. The app explains each one before it fires.

**Screen 4: Quick Config** (only if relevant)
- Driving: "Which Bluetooth device is your car?" → list of paired devices → tap
- Home/Work: "Where's home?" → map centered on current location → tap to confirm → same for work

**Screen 5: Connect to OpenClaw**
- "Paste your Gateway URL" field
- "Paste your webhook token" field
- OR: "Scan QR" button (Gateway shows QR in terminal via `openclaw qr`)
- [Test Connection] button → shows green check or error

**Screen 6: Done**
"SenseKit is active. You'll see your first event the next time you wake up, start driving, or arrive home."
Shows the debug timeline (empty but ready).

### 7.2 Time budget
- Screens 1–2: 15 seconds
- Screen 3: 30 seconds (tapping Allow on 2–3 dialogs)
- Screen 4: 45 seconds (picking car BT + confirming home/work pins)
- Screen 5: 30 seconds (pasting URL + token)
- Screen 6: 5 seconds
- **Total: ~2 minutes**

### 7.3 The Boost Precision screen (Settings → Boost)
After initial setup, Settings offers:

"Make your events even more precise with Shortcuts automations."

Each boost shows:
- Current detection confidence for that event
- What the Shortcut adds
- "Add Shortcut" button → deep-links to Shortcuts with pre-filled template
- Badge showing "Active" if the Shortcut is configured

Available boosts:
- Wake: Alarm stopped → SenseKit (confidence: 0.85 → 0.98)
- Focus: Focus on/off → SenseKit (enables a currently unavailable event)
- Workout: Workout start/end → SenseKit (adds instant detection, removes HealthKit delay)

---

## 8. Privacy, security, and App Review posture

### 8.1 Defaults (unchanged from v2)
- Off-device raw health values: **off**
- Exact GPS off-device: **off** (only `place.type: "home" | "work" | "other"`)
- Calendar titles off-device: **off** (only `in_meeting: bool` + `next_meeting_in_min`)
- Third-party AI sharing: explicit opt-in
- One-tap revoke
- Local audit trail

### 8.2 Permission matrix

| Feature | Motion | Location | Bluetooth | HealthKit | Notification |
|---------|--------|----------|-----------|-----------|-------------|
| Wake Brief | Required | — | — | — | Optional |
| Driving Mode | Required | Optional | Optional (car picker) | — | Optional |
| Home / Work | — | Required (Always) | — | — | Optional |
| Workout | — | — | — | Required | Optional |
| Focus (boost) | — | — | — | — | — |

### 8.3 Audit log
Every outbound event logs: event type, timestamp, destination, fields included, policy applied, delivery result. Viewable in-app. Exportable as JSON. Auto-pruned after 90 days.

---

## 9. Delivery and retry semantics

- Outbound HTTPS POST to Gateway webhook endpoint
- Retry policy: 3 attempts with exponential backoff (1s, 5s, 30s)
- Offline queue: SQLite-backed, max 100 events, FIFO
- Deduplication: event ID + type + 15-minute window
- Stale snapshot: if snapshot enrichment fails, deliver event with partial snapshot + `enrichment_failed: true` flag
- If Gateway unreachable after all retries: queue for later, show "offline" badge in app

---

## 10. What the competition can't easily replicate

### The "curl in Discord" problem
Someone could post:
```bash
curl -X POST http://gateway/hooks/wake -d '{"text": "I woke up"}'
```
This does ~10% of what SenseKit does. It's a manual webhook, not a context runtime. SenseKit's advantage is automatic:
- **Passive detection** — no user action required for 9 of 11 events
- **Corroboration** — multi-signal confidence, not a single trigger
- **Snapshot enrichment** — calendar, place, device state bundled with every event
- **Policy engine** — modality switching, allowed/blocked actions
- **Cooldowns + dedup** — no flapping, no duplicate events
- **Audit log** — every event traceable
- **Debug timeline** — see exactly what triggered what and when

None of this exists in a curl command.

---

## 11. Implementation phases

### Phase 1 — Passive detection + webhook delivery
**Goal:** Working demo for wake + driving with zero Shortcuts required.

Build:
- SwiftUI app with feature picker + permissions + onboarding
- CoreMotion collector (activity type, pickup detection)
- CoreBluetooth collector (car BT with state restoration)
- UIDevice collector (battery, charging state)
- Event engine with corroboration model + cooldowns
- HTTPS delivery client with retry + offline queue
- Debug timeline view
- OpenClaw webhook integration
- Basic audit log

Success criteria:
- Wake brief fires on real wake with >80% precision
- Driving mode activates on car BT connect with >90% precision
- Events delivered to Gateway within 10 seconds
- Zero Shortcuts required

### Phase 2 — Location + workout + skill
**Goal:** Home/work events + workout events + packaged OpenClaw skill.

Build:
- CoreLocation region monitoring (home/work geofences)
- HealthKit observer query (workout events)
- EventKit reader (calendar snapshot enrichment)
- Location setup UI (map pin picker)
- OpenClaw skill package
- One-command install docs

### Phase 3 — Shortcuts boost + plugin + polish
**Goal:** Optional precision boosts + richer agent tooling.

Build:
- App Intents for Shortcuts integration (receive trigger signals)
- "Boost Precision" settings screen
- Pre-built Shortcut templates
- `@sensekit/openclaw` gateway plugin (cached state, tools, admin)
- Focus on/off event (Shortcuts-only)

### Phase 4 — Optional Watch / BLE
**Goal:** Premium enrichment for advanced users.

Build:
- Watch companion (workout enrichment, live HR mode)
- BLE wearable path (selected devices, bench-tested)
- Advanced policy presets

---

## 12. Key risks and mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Passive wake detection false positives | High | Require 2+ corroborating signals + morning time window. Cooldown prevents double-fire. Shortcuts boost available for users who want near-certainty. |
| CoreBluetooth state restoration unreliable on new iOS | High | Bench test on iOS 19 beta. Fall back to CoreMotion automotive-only detection if BLE breaks. |
| HealthKit background delivery delayed/unreliable | Medium | Acceptable for workout events (delay is okay). Do not depend on it for time-critical events like wake/driving. |
| Apple rejects app | High | No data sale, no health claims, minimal sharing, explicit AI disclosure, clear privacy manifest. |
| "Too many permissions" scares users | Medium | Feature picker means users only see permissions for features they enabled. Explain each one before the dialog. |
| OpenClaw community builds a simpler alternative | Medium | Passive detection + corroboration + enrichment + policy is genuinely hard to replicate with a curl command. Ship fast. |

---

## 13. Success metrics

### Product
- First useful event within 3 minutes of setup (not 15)
- >80% of activated users enable at least one feature (not "trigger pack")
- Wake detection precision >85% without Shortcuts, >95% with Shortcuts boost
- Driving detection precision >90% with car BT, >75% without
- 30-day retention driven by at least one always-on feature

### Technical
- P0 event false-positive rate <10%
- Median event-to-Gateway latency <10 seconds
- Offline queue drains without duplicates
- Battery impact <5% daily for wake + driving features
- Zero Shortcuts required for 9 of 11 events

### GTM
- Publishable ClawHub skill
- One-command OpenClaw install path
- Three demo recipes: wake brief, driving-safe mode, workout follow-up
- Public video demo showing download → first event in under 3 minutes

---

## 14. Final recommendation

Build this. The v3 version.

The key insight: **passive-first detection with corroboration is good enough for 9 of 11 events, and Shortcuts can boost the remaining gap for power users.** This is the UX that makes the product accessible to every OpenClaw user, not just the ones who understand iOS Shortcuts.

The winning product is:

> **SenseKit is an open-source context runtime that passively detects real-world transitions and delivers policy-aware events to OpenClaw — and it works the moment you open the app.**
