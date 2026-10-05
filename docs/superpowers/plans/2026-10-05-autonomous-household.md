# LIFEBOX LIVE Autonomous Household Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the verified Plan 01 simulation foundation into a six-resident autonomous household with stable identities, concurrent SmartObject usage, movement intents, Godot 3D navigation adapters, and stuck-agent recovery.

**Architecture:** The deterministic simulation remains headless and owns decisions, needs, actions, reservations, and logical destinations. 3D movement is isolated behind a runtime adapter: simulation emits movement intents, while a `CharacterBody3D + NavigationAgent3D` scene follows them and reports arrival/failure back. This prevents render FPS or NavigationServer timing from changing simulation decisions.

**Tech Stack:** Godot 4.7.2, GDScript, CharacterBody3D, NavigationAgent3D, NavigationRegion3D, SceneTree headless tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-05-lifebox-live-design.md`

## Global Constraints

- Godot version: 4.7.2.
- GDScript first.
- Simulation behavior must remain independent of render FPS.
- Fixed-seed worlds must remain reproducible.
- LLM/network/TikTok remain outside the household simulation.
- 3D navigation must not be required for headless decision tests.
- Runtime character uses `CharacterBody3D` and `move_and_slide()` with no arguments.
- NavigationAgent3D path queries happen in physics processing after NavigationServer synchronization.
- All resident IDs are non-empty and unique.
- SmartObject reservations must be cleaned after completion, cancellation, target loss, or stuck recovery.

## Review Focus

1. Duplicate/empty resident IDs must be rejected without corrupting executor state.
2. Destroying or unregistering a SmartObject during an active action must cancel safely and release logical ownership.
3. Six residents competing for one object must never share a single-capacity reservation.
4. A navigation target that never becomes reachable must time out into recovery instead of permanently blocking the resident.
5. Runtime 3D movement may lag or fail, but must not mutate deterministic utility scoring or RNG order.

---

### Task 1: Harden Plan 01 invariants for multi-resident use

**Files:**
- Modify: `scripts/core/simulation_clock.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/unit/test_simulation_clock_safety.gd`
- Create: `tests/unit/test_household_identity.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `SimulationClock.set_time_scale(value: float)` always stores a finite value in `0..20`.
  - `SimulationWorld.add_character(character: CharacterState) -> bool` rejects null, empty ID, and duplicate ID.

- [ ] Write RED tests for NaN time scale, empty resident ID, duplicate ID, and six distinct valid IDs.
- [ ] Run headless suite and verify only the new assertions fail.
- [ ] Implement finite time-scale sanitization and boolean resident admission.
- [ ] Run full headless suite; expected PASS.
- [ ] Commit: `fix: harden household simulation invariants`.

### Task 2: Household roster and six-resident fixture

**Files:**
- Create: `scripts/simulation/household/household_state.gd`
- Create: `tests/fixtures/six_resident_household_fixture.gd`
- Create: `tests/unit/test_household_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `CharacterState`.
- Produces:
  - `class_name HouseholdState`
  - `func add_resident(character: CharacterState) -> bool`
  - `func remove_resident(character_id: StringName) -> bool`
  - `func get_resident(character_id: StringName) -> CharacterState`
  - `func residents() -> Array[CharacterState]`

- [ ] Write RED tests for unique membership, stable lookup, safe removal, and six-resident fixture creation.
- [ ] Verify failure.
- [ ] Implement minimal roster container with deterministic insertion order.
- [ ] Run suite; expected PASS.
- [ ] Commit: `feat: add six resident household roster`.

### Task 3: SmartObject logical destination and lifecycle

**Files:**
- Modify: `scripts/simulation/interactions/smart_object.gd`
- Create: `scripts/simulation/interactions/smart_object_registry.gd`
- Create: `tests/unit/test_smart_object_registry.gd`
- Modify: `tests/unit/test_smart_object.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - SmartObject fields: `object_id: StringName`, `interaction_point: Vector3`.
  - `class_name SmartObjectRegistry`
  - `register_object(object: SmartObject) -> bool`
  - `unregister_object(object_id: StringName) -> bool`
  - `get_object(object_id: StringName) -> SmartObject`
  - signal `object_removed(object_id: StringName)`

- [ ] Write RED tests for unique object IDs and removal notification.
- [ ] Add regression test: unregistering a reserved target makes it unavailable and does not leave the registry returning a freed/stale object.
- [ ] Implement registry and logical destination metadata.
- [ ] Run suite; expected PASS.
- [ ] Commit: `feat: add smart object registry and destinations`.

### Task 4: Movement intent state

**Files:**
- Create: `scripts/simulation/movement/movement_intent.gd`
- Create: `scripts/simulation/movement/movement_state.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_movement_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `class_name MovementIntent`: `target_object_id`, `target_position`, `arrival_radius`.
  - `class_name MovementState`: status `idle | moving | arrived | failed`, elapsed simulated seconds, retry count.
  - `CharacterState.movement`.

- [ ] Write RED tests for state transitions and finite target position validation.
- [ ] Verify failure.
- [ ] Implement pure-data movement intent/state classes.
- [ ] Run suite; expected PASS.
- [ ] Commit: `feat: add deterministic movement intent state`.

### Task 5: Move-before-interact action flow

**Files:**
- Modify: `scripts/simulation/actions/action_executor.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_move_before_interact.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: SmartObject interaction point, CharacterState movement state.
- Produces:
  - `SimulationWorld.report_arrival(character_id, target_object_id) -> bool`
  - `SimulationWorld.report_movement_failure(character_id, target_object_id) -> bool`
  - ActionExecutor waits in movement phase before interaction duration begins.

- [ ] Write RED test: selected Eat reserves fridge and sets movement target but does not apply hunger until arrival + interaction completion.
- [ ] Write RED test: movement failure cancels action and releases reservation.
- [ ] Implement two-phase action execution: `moving -> interacting -> complete`.
- [ ] Run full suite; expected PASS.
- [ ] Commit: `feat: require arrival before resident interactions`.

### Task 6: Runtime CharacterBody3D navigation adapter

**Files:**
- Create: `scenes/characters/resident_actor_3d.tscn`
- Create: `scripts/presentation/characters/resident_actor_3d.gd`
- Create: `tests/runtime/test_resident_actor_contract.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Scene:
  - root `CharacterBody3D`
  - child `NavigationAgent3D`
- Script:
  - `bind_character(character_id: StringName) -> void`
  - `set_movement_target(target: Vector3, arrival_radius: float) -> void`
  - `stop_movement() -> void`
  - signals `movement_arrived(character_id)`, `movement_failed(character_id)`

- [ ] Write RED structural test that scene loads, root is CharacterBody3D, child NavigationAgent3D exists, and required methods/signals exist.
- [ ] Implement scene and adapter.
- [ ] Runtime behavior follows Godot 4.7 contract: wait until navigation map iteration is non-zero; query `get_next_path_position()` during physics; set velocity; call `move_and_slide()`; use avoidance safe velocity when enabled.
- [ ] Run script scan + headless contract suite; expected PASS.
- [ ] Commit: `feat: add 3d resident navigation adapter`.

### Task 7: Minimal blockout house navigation scene

**Files:**
- Create: `scenes/world/household_blockout.tscn`
- Create: `scripts/presentation/world/household_blockout.gd`
- Create: `tests/runtime/test_household_blockout_contract.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Scene contains:
  - `NavigationRegion3D`
  - floor/blockout geometry
  - six resident spawn markers
  - fridge marker
  - six bed markers
  - bathroom/shower marker
  - sofa marker

- [ ] Write RED scene contract test for required nodes/markers and six unique spawn points.
- [ ] Implement simple 3D blockout scene with no final art.
- [ ] Ensure navigation data is authored/baked in a form loadable by Godot 4.7.2.
- [ ] Run script scan and scene contract tests; expected PASS.
- [ ] Commit: `feat: add household navigation blockout`.

### Task 8: Six-resident concurrency

**Files:**
- Create: `tests/integration/test_six_resident_contention.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: six-resident fixture and single-capacity SmartObjects.
- Produces: concurrent selection without double-reservation or null action state.

- [ ] Write RED test with six hungry residents competing for one fridge and multiple beds.
- [ ] Assert at most one resident owns the fridge reservation at any time.
- [ ] Assert losing residents remain valid and retry later rather than stealing the target.
- [ ] Implement only scheduling changes needed to satisfy deterministic contention behavior.
- [ ] Run suite; expected PASS.
- [ ] Commit: `feat: support six resident smart object contention`.

### Task 9: Stuck-agent watchdog and recovery

**Files:**
- Create: `scripts/simulation/movement/stuck_recovery_policy.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_stuck_recovery.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - configurable movement timeout, default `30.0` simulated seconds;
  - max retry count, default `2`;
  - after exhaustion: cancel action, release reservation, movement status `failed`, resident returns to Idle.

- [ ] Write RED test where arrival is never reported.
- [ ] Assert retry count increments deterministically.
- [ ] Assert final failure releases target and resident can choose another action later.
- [ ] Implement watchdog/retry policy.
- [ ] Run suite; expected PASS.
- [ ] Commit: `feat: recover residents from stuck movement`.

### Task 10: Household soak and Plan 02 documentation

**Files:**
- Create: `tests/soak/test_six_resident_household_soak.gd`
- Create: `docs/architecture/autonomous-household.md`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Six residents, fixed seed, repeated contention, simulated arrivals/failures.
- No rendering required for soak.

- [ ] Run a deterministic six-resident accelerated test covering at least 8 simulated hours.
- [ ] Assert no duplicate IDs, no double reservations, no invalid needs, no permanent stuck movement, and identical history under same seed.
- [ ] Document simulation/runtime navigation boundary and public contracts.
- [ ] Run full GitHub Actions suite on final HEAD.
- [ ] Inspect final log for hidden Godot WARNING/SCRIPT ERROR/ERROR lines.
- [ ] Commit: `test: seal autonomous household foundation`.

# Plan 02 completion gate

Plan 02 is complete only when:

- six residents coexist with unique stable IDs;
- one-capacity SmartObjects are never double-reserved;
- Eat/Sleep interactions require logical arrival before effects are applied;
- failed navigation can recover without deadlock;
- CharacterBody3D/NavigationAgent3D adapter loads and satisfies the Godot 4.7 runtime contract;
- blockout house exposes six spawn points and required household destinations;
- eight simulated household hours complete deterministically;
- all headless/runtime contract tests pass with no hidden Godot errors.

# Deferred to Plan 03

- relationships;
- jobs and economy;
- memory;
- social conversations;
- animation state machine polish;
- final character models and environment art;
- persistence;
- Fate Engine / TikTok bridge;
- StoryDirector / CameraDirector.
