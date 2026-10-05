# Persistence & Deterministic Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add versioned, corruption-tolerant save/load and deterministic replay so LIFEBOX LIVE can resume an autonomous world after restart without changing simulation outcomes.

**Architecture:** Persist simulation-authoritative state as a JSON-compatible versioned snapshot while requiring scene/topology SmartObjects to be registered before restore. Restore uses validate-first/apply-second semantics so corrupt or incompatible data never partially mutates a live world. RNG `seed` and `state` are persisted explicitly; replay stores only deterministic external inputs since a snapshot and replays them in order.

**Tech Stack:** Godot 4.7.2, GDScript, `FileAccess`, `DirAccess.rename_absolute()`, `ProjectSettings.globalize_path()`, JSON, existing headless TDD harness.

**Spec:** `docs/superpowers/specs/2026-10-05-lifebox-live-design.md`

## Global Constraints

- Godot **4.7.2** only.
- GDScript-first.
- Simulation remains independent of render FPS.
- No network or LLM dependency is required for save/load/replay.
- Existing Plan 01–03 tests must remain green.
- All restore validation must finish before mutating the target `SimulationWorld`.
- Save schema is explicit and versioned; unknown future versions are rejected.
- Scene topology is not recreated from JSON: required SmartObjects must already be registered in the destination world.
- RNG restore order is `seed` first, then a previously captured `state` value.
- Save writes use a temporary file plus backup/rename recovery; a failed write must not destroy the previous good save.
- Replay records deterministic external inputs, not generated AI decisions.
- Default save path for production-facing helpers: `user://lifebox_live/save_01.json`.

## Review Focus

1. **Truncated/corrupt main save:** load must reject it without mutating the world and recover from a valid `.bak` file — covered by Task 8.
2. **Future/unknown schema version:** must be rejected rather than guessed or silently downgraded — covered by Task 1 and Task 7.
3. **Duplicate or missing stable IDs:** duplicate residents, relationship endpoints, or required active-action targets must fail validation before apply — covered by Tasks 2, 4, and 6.
4. **Saved active action targets no longer present in topology:** restore must cancel that action safely and leave no stale SmartObject reservation — covered by Task 4.
5. **RNG divergence after load:** the first random decision after restore must match an uninterrupted control world exactly — covered by Tasks 6 and 10.

---

### Task 1: Versioned Save Envelope & Validator

**Files:**
- Create: `scripts/persistence/save_schema.gd`
- Create: `scripts/persistence/snapshot_validator.gd`
- Create: `tests/unit/test_save_schema.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `AppConstants.PROJECT_ID`.
- Produces:
  - `SaveSchema.CURRENT_VERSION: int = 1`
  - `SaveSchema.create_envelope(payload: Dictionary) -> Dictionary`
  - `SnapshotValidator.validate_envelope(snapshot: Dictionary) -> Array[String]`

- [ ] **Step 1: Write the failing test**
  - Assert envelope contains `project_id`, `schema_version == 1`, and `payload`.
  - Assert missing/empty project id, non-integer version, negative version, wrong project id, and missing payload are rejected.
  - Assert `schema_version > CURRENT_VERSION` is rejected as unsupported-future data.

- [ ] **Step 2: Run the full headless suite and verify RED**
  - Run: `godot --headless --path . -s res://tests/test_runner.gd`
  - Expected: failure because `SaveSchema` does not exist.

- [ ] **Step 3: Implement the envelope and validator**
  - Validator returns deterministic error strings and never mutates input.

- [ ] **Step 4: Run suite and inspect logs**
  - Expected: new suite passes; no hidden `SCRIPT ERROR / ERROR / WARNING`.

- [ ] **Step 5: Commit**
  - Commit: `feat: add versioned save envelope`

---

### Task 2: Character Snapshot Codec

**Files:**
- Create: `scripts/persistence/character_snapshot_codec.gd`
- Create: `tests/unit/test_character_snapshot_codec.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `CharacterState`, `NeedProfile`, `PersonalityState`, `MemoryStore`, `JobState`.
- Produces:
  - `CharacterSnapshotCodec.encode(character: CharacterState) -> Dictionary`
  - `CharacterSnapshotCodec.validate(data: Dictionary) -> Array[String]`
  - `CharacterSnapshotCodec.decode_stable_state(data: Dictionary) -> CharacterState`

- [ ] **Step 1: Write the failing test**
  - Round-trip stable id, display name, six needs + decay rates, eight personality traits, money, memory events, and job definition/worked seconds.
  - Money must remain finite/non-negative.
  - Memory count must not exceed capacity.
  - Duplicate memory event IDs and empty resident IDs must fail validation.
  - Current in-flight action/movement is intentionally excluded here and owned by Task 4.

- [ ] **Step 2: Verify RED**
  - Expected: missing codec.

- [ ] **Step 3: Implement JSON-compatible encoding**
  - Use strings/numbers/arrays/dictionaries only.
  - Decode only after `validate()` returns no errors.

- [ ] **Step 4: Verify GREEN + old suites**

- [ ] **Step 5: Commit**
  - Commit: `feat: serialize resident stable state`

---

### Task 3: Relationship, Economy & Household Runtime State

**Files:**
- Create: `scripts/persistence/social_economy_snapshot_codec.gd`
- Modify: `scripts/simulation/economy/economy_system.gd`
- Modify: `scripts/simulation/economy/household_expense_system.gd`
- Create: `tests/unit/test_social_economy_snapshot_codec.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `RelationshipGraph.all_relationships()`, `EconomySystem.transactions()`.
- Produces:
  - `EconomySystem.capture_persistence_state(max_transactions: int = 512) -> Dictionary`
  - `EconomySystem.restore_persistence_state(data: Dictionary) -> bool`
  - `SocialEconomySnapshotCodec.encode_relationships(graph: RelationshipGraph) -> Array`
  - `SocialEconomySnapshotCodec.validate_relationships(data: Array, resident_ids: Dictionary) -> Array[String]`
  - `SocialEconomySnapshotCodec.restore_relationships(data: Array, graph: RelationshipGraph) -> bool`

- [ ] **Step 1: Write failing tests**
  - Round-trip directed relationship edges and bounded values.
  - Reject relationship endpoints absent from the resident roster.
  - Persist economy transaction sequence plus at most the newest **512** transaction records.
  - Persist `daily_amount`, `arrears`, and `processed_days`.
  - Restore must preserve the next deterministic economy transaction id.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement minimal persistence state APIs**

- [ ] **Step 4: Verify GREEN + clean logs**

- [ ] **Step 5: Commit**
  - Commit: `feat: persist social and economy state`

---

### Task 4: Active SmartObject Action Snapshot & Safe Restore

**Files:**
- Modify: `scripts/simulation/actions/action_executor.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `scripts/persistence/action_snapshot_codec.gd`
- Create: `tests/integration/test_action_snapshot_restore.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: registered `SmartObject.object_id`, `InteractionDefinition.id`, resident id.
- Produces:
  - `ActionExecutor.capture_state() -> Dictionary`
  - `ActionExecutor.restore_state(data: Dictionary, character: CharacterState, smart_object: SmartObject, interaction: InteractionDefinition) -> bool`
  - `SimulationWorld.get_smart_object(object_id: StringName) -> SmartObject`
  - `SimulationWorld.get_character(character_id: StringName) -> CharacterState`
  - `ActionSnapshotCodec.validate(data: Dictionary, world: SimulationWorld) -> Array[String]`

- [ ] **Step 1: Write failing integration tests**
  - Save/restore a resident while **moving** to a reserved SmartObject: target id, elapsed movement time, retry count, action id, and reservation must restore.
  - Save/restore while **interacting**: remaining interaction time must restore without reapplying effects early.
  - If the saved target object or interaction no longer exists, restore must safely cancel to idle and leave the object unreserved.
  - Duplicate active claims on one single-capacity SmartObject must be rejected before apply.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement executor/world lookup persistence APIs**
  - Do not serialize Node instance IDs or scene paths.

- [ ] **Step 4: Verify GREEN + contention/stuck regression**

- [ ] **Step 5: Commit**
  - Commit: `feat: restore in flight household actions`

---

### Task 5: Social Session Runtime Snapshot

**Files:**
- Modify: `scripts/simulation/social/social_session.gd`
- Modify: `scripts/simulation/social/social_reservation_book.gd`
- Modify: `scripts/simulation/social/social_system.gd`
- Create: `tests/integration/test_social_snapshot_restore.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `SocialReservationBook.capture_state() -> Dictionary`
  - `SocialReservationBook.restore_state(data: Dictionary, valid_resident_ids: Dictionary) -> bool`
  - `SocialSystem.capture_persistence_state() -> Dictionary`
  - `SocialSystem.restore_persistence_state(data: Dictionary, residents: Array) -> bool`

- [ ] **Step 1: Write failing tests**
  - Active pair, action id, remaining seconds, session sequence, and SocialSystem simulation time round-trip.
  - Completed-but-not-yet-drained session queue round-trips exactly once.
  - Missing resident, duplicate resident across sessions, self-session, invalid duration, or duplicate session id rejects restore without partial locks.
  - Cancel after restore produces no social outcome.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement state capture/restore**

- [ ] **Step 4: Verify GREEN + Task 6–8 regressions**

- [ ] **Step 5: Commit**
  - Commit: `feat: persist social runtime sessions`

---

### Task 6: World Snapshot Codec + RNG Continuity

**Files:**
- Modify: `scripts/core/simulation_clock.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `scripts/persistence/world_snapshot_codec.gd`
- Create: `tests/integration/test_world_snapshot_roundtrip.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `SimulationClock.capture_state() -> Dictionary`
  - `SimulationClock.restore_state(data: Dictionary) -> bool`
  - `SimulationWorld.capture_persistence_state() -> Dictionary`
  - `SimulationWorld.validate_persistence_state(data: Dictionary) -> Array[String]`
  - `SimulationWorld.restore_persistence_state(data: Dictionary) -> bool`
  - `WorldSnapshotCodec.encode(world: SimulationWorld) -> Dictionary`
  - `WorldSnapshotCodec.restore(world: SimulationWorld, snapshot: Dictionary) -> Array[String]`

- [ ] **Step 1: Write failing round-trip tests**
  - Persist clock time scale/time, fixed-step pending seconds, processed seconds, economy pending seconds, resident order, stable resident state, active action state, relationships, economy, household expenses, social runtime, RNG `seed` and `state`.
  - Capture RNG state, draw next random value in control, restore snapshot into equivalent topology, and assert restored next random value/decision is identical.
  - Set RNG `seed` before restoring captured `state`.
  - Duplicate resident IDs or malformed subsystem data must make validation fail before target world mutation.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement orchestration**
  - Restore order: validate all → stable residents → relationships/economy → actions/reservations → social sessions → clock/runtime counters → RNG seed → RNG state.

- [ ] **Step 4: Verify GREEN + 24-hour soak regression**

- [ ] **Step 5: Commit**
  - Commit: `feat: snapshot and restore simulation world`

---

### Task 7: Schema Migration Pipeline

**Files:**
- Create: `scripts/persistence/save_migrator.gd`
- Create: `tests/unit/test_save_migrator.gd`
- Create: `tests/fixtures/save_v0.json`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `SaveMigrator.migrate(snapshot: Dictionary) -> Dictionary`
  - `SaveMigrator.can_migrate(version: int) -> bool`

- [ ] **Step 1: Write failing tests**
  - Synthetic v0 uses payload key `characters`; v1 uses `residents`.
  - v0→v1 preserves all values while renaming the key and setting `schema_version = 1`.
  - Migration input remains unchanged.
  - Unknown future version and negative version return an empty result / explicit unsupported error contract.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement sequential migration registry**
  - One function per version hop; no multi-version shortcuts.

- [ ] **Step 4: Verify GREEN**

- [ ] **Step 5: Commit**
  - Commit: `feat: add save schema migration pipeline`

---

### Task 8: Atomic SaveService & Backup Recovery

**Files:**
- Create: `scripts/persistence/save_service.gd`
- Create: `tests/integration/test_save_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `WorldSnapshotCodec`, `SaveSchema`, `SaveMigrator`.
- Produces:
  - `SaveService.save_world(world: SimulationWorld, path: String = "user://lifebox_live/save_01.json") -> Error`
  - `SaveService.load_into_world(world: SimulationWorld, path: String = "user://lifebox_live/save_01.json") -> Dictionary`
  - Load result keys: `ok: bool`, `source: String` (`"main"` or `"backup"`), `errors: Array[String]`.

- [ ] **Step 1: Write failing filesystem tests**
  - Successful save writes valid JSON and later loads it.
  - Write path uses `<path>.tmp`; prior good save is retained as `<path>.bak` during replacement.
  - Corrupt/truncated main file + valid backup loads from backup.
  - Corrupt main + corrupt backup leaves the destination world unchanged.
  - Unknown future schema leaves world unchanged.
  - Failed replacement must not delete the previous good save.

- [ ] **Step 2: Verify RED**
  - Use a unique `user://lifebox_live/tests/` path and delete test artifacts after each case.

- [ ] **Step 3: Implement temp/write/close/rename recovery**
  - Convert `user://` paths with `ProjectSettings.globalize_path()` before `DirAccess.rename_absolute()`.
  - Never claim OS-level durability beyond what Godot APIs guarantee; the backup is the crash-recovery layer.

- [ ] **Step 4: Verify GREEN + clean logs**

- [ ] **Step 5: Commit**
  - Commit: `feat: add atomic save service with backup recovery`

---

### Task 9: Deterministic Replay Input Log

**Files:**
- Create: `scripts/replay/replay_event.gd`
- Create: `scripts/replay/replay_log.gd`
- Create: `scripts/replay/replay_player.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_replay_log.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `ReplayEvent(sequence: int, kind: StringName, payload: Dictionary)`
  - `ReplayLog.append(kind: StringName, payload: Dictionary) -> bool`
  - `ReplayLog.events() -> Array[ReplayEvent]`
  - `ReplayPlayer.replay(world: SimulationWorld, initial_snapshot: Dictionary, events: Array) -> Array[String]`
  - Deterministic input kinds for this plan: `advance`, `movement_arrived`, `movement_failed`.
  - `ReplayLog.MAX_EVENTS = 4096`; overflow rejects append so the caller can force a new checkpoint instead of silently dropping reconstructive input.

- [ ] **Step 1: Write failing replay tests**
  - Record an initial snapshot, a sequence of `advance` deltas and navigation feedback, then replay into identical topology and assert final snapshot equality.
  - Event sequence numbers must be monotonic and deterministic.
  - Unknown event kind, malformed payload, non-finite delta, or more than 4096 events must fail without partially advancing replay world.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement replay log/player**
  - Replay applies external inputs in recorded order; AI/utility/social decisions are regenerated from restored RNG state.

- [ ] **Step 4: Verify GREEN**

- [ ] **Step 5: Commit**
  - Commit: `feat: add deterministic input replay`

---

### Task 10: Save-Load-Continue & Replay Soak

**Files:**
- Create: `tests/soak/test_persistence_replay_soak.gd`
- Create: `docs/architecture/persistence-replay.md`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes all Tasks 1–9.
- Produces final Plan 04 verification.

- [ ] **Step 1: Write the final failing soak**
  - Build two identical six-resident Plan 03 worlds.
  - Run both for 4 simulated hours with deterministic navigation feedback.
  - Snapshot world B, construct a fresh equivalent topology, restore B into it.
  - Continue control A and restored B for another 4 simulated hours with identical external input sequence.
  - Assert final full snapshots are identical, including RNG state, resident order/state, active actions, relationships, economy, expenses, social runtime, and clocks.
  - Separately replay a bounded recorded segment from its initial snapshot and assert final snapshot equality.
  - Corrupt the primary disk save and verify backup recovery returns the same snapshot.
  - Assert all restored SmartObject/social reservations are valid and non-duplicated.

- [ ] **Step 2: Verify RED if any final integration is missing**

- [ ] **Step 3: Fix only integration gaps revealed by the soak**

- [ ] **Step 4: Final verification**
  - Run: `godot --headless --path . -s res://tests/test_runner.gd`
  - Run both GitHub workflows on the documented HEAD.
  - Inspect logs for hidden `SCRIPT ERROR / ERROR / WARNING`.
  - Existing Plan 01–03 33 suites must remain green.

- [ ] **Step 5: Document and commit**
  - Document schema ownership, restore ordering, topology requirements, atomic-write recovery, migration policy, replay contract, and known deferred state.
  - Commit: `docs: document persistence and replay architecture`

## Self-Review

- **Spec coverage:** versioned persistence, atomic save/backup recovery, migrations, RNG continuity, active action/social restore, and deterministic replay are each owned by a task.
- **Step scan:** each task has one RED → GREEN deliverable and an independently reviewable boundary.
- **Type consistency:** all codecs use JSON-compatible Dictionary/Array payloads; world restore accepts pre-registered topology; replay consumes snapshots from the same `WorldSnapshotCodec`.
- **Review Focus:** corrupt files, future versions, duplicate IDs, missing active targets, and RNG divergence each have an explicit test owner.
- **Proportion:** implementation bodies are left to execution; the plan fixes interfaces, restore order, schema values, and test contracts only.
