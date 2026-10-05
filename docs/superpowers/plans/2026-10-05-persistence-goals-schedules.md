# LIFEBOX LIVE Persistence, Goals & Schedules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add schema-versioned save/restore with deterministic continuation, plus persistent daily resident goals and schedule state.

**Architecture:** Persistence is split into pure JSON-safe snapshot codecs and a filesystem-only SaveService. SimulationWorld is restored into an already constructed world with the same stable SmartObject IDs; all references are validated before mutation. Resident goals/schedules are pure data and participate in snapshots. Active SmartObject actions, movement, social sessions, RNG state and timing accumulators are preserved so save→load continuation can match uninterrupted simulation.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, FileAccess, DirAccess, SceneTree headless tests.

**Spec:** `docs/superpowers/specs/2026-10-05-lifebox-live-design.md`

## Global Constraints

- Godot 4.7.2.
- GDScript-first.
- Existing 34 Plan 01–03 suites must remain green.
- Save format uses JSON-safe primitives only.
- Save schema starts at version `1`.
- RNG `seed` and `state` are serialized as decimal strings to preserve 64-bit exactness through JSON.
- Restore must not partially mutate a live world when validation fails.
- Environment definitions are not duplicated in saves; active actions reference stable `SmartObject.object_id` and interaction IDs.
- LLM, TikTok and network access remain unnecessary.
- Filesystem saves live under `user://lifebox/saves/`.
- One backup save is retained for recovery from a corrupt primary file.

## Review Focus

1. Corrupt/partial JSON: load returns failure and leaves live world unchanged; backup may be used when primary cannot be parsed.
2. Missing SmartObject or interaction referenced by an active action: restore rejects before mutation.
3. 64-bit RNG state precision: string round-trip restores exact next random values.
4. Save during active movement/social session: remaining time, reservation ownership and participants restore exactly without double-reservation.
5. Repeated load/save and schema migration: no duplicate residents/memories/transactions and no sequence-ID rollback.

---

### Task 1: Schema envelope and migration pipeline

**Files:**
- Create: `scripts/persistence/save_schema.gd`
- Create: `scripts/persistence/save_migrator.gd`
- Create: `tests/unit/test_save_schema.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `SaveSchema.CURRENT_VERSION: int = 1`
- `SaveSchema.wrap(world_data: Dictionary) -> Dictionary`
- `SaveSchema.validate_envelope(snapshot: Dictionary) -> Array[String]`
- `SaveMigrator.migrate(snapshot: Dictionary) -> Dictionary`

- [ ] RED tests: missing version/world rejected; future version rejected; v0 legacy fixture migrates deterministically to v1; migration does not mutate caller dictionary.
- [ ] Implement envelope and minimal v0→v1 migration.
- [ ] Full suite PASS.
- [ ] Commit: `feat: add save schema and migration pipeline`.

### Task 2: Persistent daily goals and schedule state

**Files:**
- Create: `scripts/simulation/goals/daily_goal.gd`
- Create: `scripts/simulation/goals/goal_state.gd`
- Create: `scripts/simulation/goals/goal_system.gd`
- Create: `scripts/simulation/schedule/schedule_state.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_goal_schedule_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `DailyGoal`: id, category, priority 0..1, target_value, progress, expires_day.
- `GoalState`: max 3 active daily goals, unique IDs, deterministic order.
- `GoalSystem.refresh_daily(character, day_index, rng) -> void`
- `ScheduleState`: day_index, planned_mode `sleep|work|social|free`, next_transition_sim_seconds.
- CharacterState owns `goals` and `schedule`.

- [ ] RED tests: bounded priorities/progress; duplicate goal rejection; max 3; same seed/personality/day gives same goals; assigned job creates work goal; schedule mode is deterministic for same state.
- [ ] Implement pure-data goal/schedule state and deterministic daily refresh.
- [ ] Full suite PASS.
- [ ] Commit: `feat: add persistent resident goals and schedules`.

### Task 3: Character snapshot codec

**Files:**
- Create: `scripts/persistence/character_snapshot_codec.gd`
- Create: `tests/unit/test_character_snapshot_codec.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `capture(character: CharacterState) -> Dictionary`
- `validate(snapshot: Dictionary) -> Array[String]`
- `restore(snapshot: Dictionary, character: CharacterState) -> bool`

**Captured state:**
- id/display name;
- all needs + decay rates;
- all personality traits;
- money/current action id;
- movement state + intent;
- memories;
- job definition/state;
- daily goals;
- schedule.

- [ ] RED round-trip test with non-default values.
- [ ] RED malformed snapshot test must not mutate target character.
- [ ] Implement JSON-safe Vector3 arrays and StringName→String normalization.
- [ ] Full suite PASS.
- [ ] Commit: `feat: add character snapshot codec`.

### Task 4: Relationship and economy snapshot APIs

**Files:**
- Modify: `scripts/simulation/relationships/relationship_graph.gd`
- Modify: `scripts/simulation/economy/economy_system.gd`
- Modify: `scripts/simulation/economy/household_expense_system.gd`
- Create: `tests/unit/test_system_snapshot_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- RelationshipGraph `snapshot_state() -> Array`, `restore_state(Array) -> bool`.
- EconomySystem `snapshot_state() -> Dictionary`, `restore_state(Dictionary) -> bool` including sequence and transaction history.
- HouseholdExpenseSystem `snapshot_state() -> Dictionary`, `restore_state(Dictionary) -> bool`.

- [ ] RED tests for exact sequence continuation after restore.
- [ ] RED invalid restore leaves existing system state unchanged.
- [ ] Implement transactional validation-then-apply restore.
- [ ] Full suite PASS.
- [ ] Commit: `feat: snapshot relationship and economy systems`.

### Task 5: Clock, RNG and world timing snapshot

**Files:**
- Modify: `scripts/core/simulation_clock.gd`
- Create: `scripts/persistence/world_timing_snapshot.gd`
- Create: `tests/unit/test_world_timing_snapshot.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- SimulationClock `snapshot_state() -> Dictionary`, `restore_state(Dictionary) -> bool`.
- WorldTimingSnapshot captures:
  - clock state;
  - RNG seed/state as strings;
  - pending/processed simulation seconds;
  - pending/processed economy seconds.

- [ ] RED RNG test: capture state, consume values, restore, next values exactly match.
- [ ] RED non-finite timing values rejected without mutation.
- [ ] Implement exact seed-before-state restore.
- [ ] Full suite PASS.
- [ ] Commit: `feat: preserve deterministic world timing and rng`.

### Task 6: Active SmartObject action snapshot/restore

**Files:**
- Modify: `scripts/simulation/actions/action_executor.gd`
- Create: `scripts/persistence/action_snapshot_codec.gd`
- Create: `tests/integration/test_active_action_restore.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- ActionExecutor `snapshot_state() -> Dictionary`.
- ActionSnapshotCodec validates target object/interaction before restore.
- `restore_executor(snapshot, character, objects_by_id, economy) -> ActionExecutor`.

- [ ] RED save while moving: object reservation, action ID, MovementIntent, retry/elapsed state restore.
- [ ] RED save while interacting: remaining interaction seconds restore; cost/reward still happens exactly once.
- [ ] RED missing object/interaction rejects with no reservation mutation.
- [ ] Implement restore using existing stable SmartObject IDs.
- [ ] Full suite PASS.
- [ ] Commit: `feat: restore active smart object actions`.

### Task 7: Active social session snapshot/restore

**Files:**
- Modify: `scripts/simulation/social/social_reservation_book.gd`
- Modify: `scripts/simulation/social/social_system.gd`
- Create: `tests/integration/test_social_restore.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- SocialReservationBook snapshot includes sequence and active sessions.
- SocialSystem snapshot includes internal simulated time and completed queue.
- Restore rebuilds pair reservations atomically.

- [ ] RED active compliment session round-trip preserves remaining time and both reservations.
- [ ] RED sequence continues without reused social session IDs.
- [ ] RED invalid duplicate participant snapshot is rejected without modifying live reservations.
- [ ] Implement validation-then-apply restore.
- [ ] Full suite PASS.
- [ ] Commit: `feat: restore active social sessions`.

### Task 8: Transactional SimulationWorld snapshot/restore

**Files:**
- Create: `scripts/persistence/world_snapshot_codec.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_world_snapshot_roundtrip.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `SimulationWorld.snapshot_state() -> Dictionary`
- `SimulationWorld.restore_state(snapshot: Dictionary) -> bool`
- `WorldSnapshotCodec.validate(snapshot, world) -> Array[String]`

**World snapshot includes:**
- timing/RNG;
- all residents;
- relationship graph;
- economy + household expenses;
- active executors;
- social state;
- goals/schedules.

- [ ] RED round-trip from non-trivial world with active movement and social state.
- [ ] RED unknown resident/object/interaction rejects before mutation.
- [ ] RED restore same snapshot twice does not duplicate memory/transactions/reservations.
- [ ] Implement preflight validation of all references before any mutation.
- [ ] Full suite PASS.
- [ ] Commit: `feat: add transactional world snapshots`.

### Task 9: Atomic JSON SaveService and backup recovery

**Files:**
- Create: `scripts/persistence/save_service.gd`
- Create: `tests/integration/test_save_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `save(slot: String, snapshot: Dictionary) -> Error`
- `load(slot: String) -> Dictionary`
- `delete(slot: String) -> Error`
- Paths under `user://lifebox/saves/`.

**Write protocol:**
1. JSON stringify snapshot.
2. Write `.tmp`, flush, close.
3. Move existing primary to `.bak`.
4. Rename temp to primary.
5. On primary parse/validation failure, attempt backup.

- [ ] RED invalid slot names rejected.
- [ ] RED save/load JSON round-trip.
- [ ] RED corrupt primary loads valid backup.
- [ ] RED failed/corrupt load returns empty snapshot and never changes a world by itself.
- [ ] Implement filesystem layer.
- [ ] Full suite PASS.
- [ ] Commit: `feat: add atomic save service with backup recovery`.

### Task 10: Deterministic save/load continuation soak

**Files:**
- Create: `tests/soak/test_save_restore_continuation.gd`
- Create: `docs/architecture/persistence-goals-schedules.md`
- Modify: `tests/test_runner.gd`

**Scenario:**
- Build two identical six-resident worlds.
- Run both for 6 simulated hours.
- Snapshot world B while at least one transient action/social session has existed during the run.
- Restore snapshot into a fresh equivalent world C.
- Continue A and C to 24 simulated hours with identical deterministic navigation feedback.

**Assertions:**
- A and C sampled histories match after restore boundary.
- RNG next values remain identical.
- money/transactions/job time match;
- relationships/memories/goals/schedules match;
- no duplicate residents/memories/transactions;
- no stale or double SmartObject/social reservations;
- household expense day count/arrears match;
- save schema v1 validates;
- full suite clean with no hidden Godot SCRIPT ERROR / ERROR / WARNING.

- [ ] Write continuation soak RED.
- [ ] Fix only restore gaps exposed by soak.
- [ ] Document snapshot ownership, schema v1, atomic file protocol and transient restore rules.
- [ ] Run final GitHub Actions on final HEAD.
- [ ] Commit: `test: seal deterministic persistence and planning`.

# Plan 04 completion gate

Plan 04 is complete only when:

- save schema v1 and migration pipeline are verified;
- resident goals/schedules are deterministic and persist;
- all current resident/social/economy state round-trips;
- active SmartObject movement/interactions restore without double effects;
- active social sessions restore without duplicate participants;
- RNG continuation is exact across JSON-safe snapshot data;
- invalid snapshots cannot partially mutate a world;
- atomic file save + backup recovery passes;
- save→load continuation matches uninterrupted simulation through 24 simulated hours;
- all prior tests remain green and final Godot logs are clean.

# Deferred

- physical workplace/commute execution for schedule blocks;
- cloud save sync;
- LLM-generated dialogue;
- TikTok Live bridge and Fate Engine;
- Story Director / Camera Director;
- final art/audio/animation polish.
