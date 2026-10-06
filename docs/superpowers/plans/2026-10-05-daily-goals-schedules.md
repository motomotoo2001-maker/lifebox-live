# Daily Goals & Schedules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic 24-hour resident schedules and daily personal goals that bias autonomous decisions without overriding critical needs.

**Architecture:** Schedule and goal state live on each `CharacterState`. A `DailyPlanningSystem` owns day rollover and deterministic goal generation. A `DecisionBiasSystem` adjusts candidate scores before `UtilityAI.choose()`; it never executes actions directly. Plan 04 persistence codecs are extended so save/load preserves the exact planner state.

**Tech Stack:** Godot 4.7.2, GDScript, existing Utility AI, Plan 04 WorldSnapshotCodec/SaveService.

**Spec:** `docs/superpowers/specs/2026-10-05-daily-goals-schedules-spec.md`

## Global Constraints

- Godot 4.7.2.
- Same seed + same initial snapshot + same external inputs must produce the same goals, choices and final snapshot.
- Schedules and goals modify scores only; they never directly execute actions.
- Critical hunger/energy must be able to override schedule and goal preference.
- No LLM or network dependency.
- Plan 01–04 tests stay green.
- All new authoritative state must round-trip through Plan 04 persistence.

## Review Focus

- Overlapping or malformed schedule blocks must fail validation instead of producing ambiguous active blocks.
- Midnight-crossing schedule blocks must resolve consistently.
- Goal generation must happen once per simulated day, including after save/load near a day boundary.
- Schedule/goal bias must never suppress a critical need candidate below a non-critical preference.
- Missing goal targets after restore must fail closed or retire the goal without corrupting resident state.

---

### Task 1: Schedule Data Model & Validation

**Files:**
- Create: `scripts/simulation/schedules/schedule_block.gd`
- Create: `scripts/simulation/schedules/schedule_definition.gd`
- Create: `tests/unit/test_schedule_definition.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `ScheduleBlock(id: StringName, kind: StringName, start_hour: float, duration_hours: float, preferred_action_tags: Array[StringName])`
  - `ScheduleDefinition.blocks: Array[ScheduleBlock]`
  - `ScheduleDefinition.validate() -> Array[String]`
  - `ScheduleDefinition.active_block_at(hour: float) -> ScheduleBlock`

- [ ] Write failing tests for valid blocks, overlap rejection, invalid hours/durations, deterministic block order and a block crossing midnight.
- [ ] Run full headless tests; expect only schedule suite failure.
- [ ] Implement minimal schedule classes and validation.
- [ ] Run full suite; expect GREEN.
- [ ] Commit: `feat: add deterministic schedule definitions`

### Task 2: Per-Resident Daily Schedule Runtime

**Files:**
- Create: `scripts/simulation/schedules/daily_schedule_state.gd`
- Create: `scripts/simulation/schedules/daily_schedule_system.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_daily_schedule_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `ScheduleDefinition.active_block_at(hour)`.
- Produces:
  - `CharacterState.schedule`
  - `DailyScheduleState.definition`
  - `DailyScheduleState.day_index: int`
  - `DailyScheduleState.active_block_id: StringName`
  - `DailyScheduleSystem.advance(character, simulation_seconds) -> void`

- [ ] Write failing tests for day index, active block changes, midnight rollover and idempotent repeated calls at the same timestamp.
- [ ] Verify RED.
- [ ] Implement schedule state/system.
- [ ] Verify GREEN.
- [ ] Commit: `feat: track resident daily schedule state`

### Task 3: Goal Definitions & Runtime State

**Files:**
- Create: `scripts/simulation/goals/goal_definition.gd`
- Create: `scripts/simulation/goals/goal_state.gd`
- Create: `scripts/simulation/goals/goal_set.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_goal_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `GoalDefinition(id, category, preferred_action_tags, priority, target_resident_id)`
  - statuses: `active/completed/failed`
  - `GoalState.progress: float` in 0..1
  - `GoalSet.MAX_ACTIVE_GOALS = 3`
  - duplicate goal IDs rejected.

- [ ] Write failing tests for validation, progress clamping, completion/failure and max-active/duplicate rules.
- [ ] Verify RED.
- [ ] Implement goal data/runtime classes.
- [ ] Verify GREEN.
- [ ] Commit: `feat: add resident goal state`

### Task 4: Deterministic Daily Goal Planner

**Files:**
- Create: `scripts/simulation/goals/daily_goal_planner.gd`
- Create: `tests/integration/test_daily_goal_planner.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes resident personality, job assignment, relationship graph and fixed-seed RNG.
- Produces:
  - `DailyGoalPlanner.generate(character, relationships, day_index, rng) -> Array[GoalState]`
  - exactly 1–3 goals when valid candidates exist;
  - no duplicate goal IDs.

- [ ] Write failing same-seed/different-personality tests and target-resident validation tests.
- [ ] Verify RED.
- [ ] Implement weighted deterministic goal generation.
- [ ] Verify GREEN.
- [ ] Commit: `feat: generate deterministic daily resident goals`

### Task 5: Schedule & Goal Decision Bias

**Files:**
- Create: `scripts/simulation/goals/decision_bias_system.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_schedule_goal_bias.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `DecisionBiasSystem.adjust(character, candidate, base_score, simulation_seconds, relationships) -> float`
  - schedule bias based on matching action tags;
  - active-goal bias based on matching action tags/target;
  - critical need protection.

- [ ] Write failing tests proving free-time/social/work bias changes equal choices but critical hunger/energy still wins.
- [ ] Verify RED.
- [ ] Apply bias in `SimulationWorld._score_interaction()` before final UtilityAI selection.
- [ ] Verify GREEN and old deterministic tests.
- [ ] Commit: `feat: bias utility decisions with schedules and goals`

### Task 6: Daily Planning System & Job/Social Hooks

**Files:**
- Create: `scripts/simulation/goals/daily_planning_system.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_daily_planning_rollover.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `DailyPlanningSystem.advance(world, simulation_seconds, rng) -> void`
  - generates goals once per day;
  - updates active schedule block;
  - retires completed/failed previous-day goals;
  - work/social goal hooks use existing job/relationship data without double-paying wages.

- [ ] Write failing rollover tests across multiple days and repeated timestamps.
- [ ] Verify RED.
- [ ] Integrate planner into fixed simulation step.
- [ ] Verify GREEN.
- [ ] Commit: `feat: run daily resident planning lifecycle`

### Task 7: Persistence Integration

**Files:**
- Modify: `scripts/persistence/character_snapshot_codec.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_goal_schedule_snapshot_restore.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Persists schedule definition/runtime, goal set, day index and planner rollover state.
- Restored residents must continue with the same next schedule/goal decision.

- [ ] Write failing stable-state round-trip and mid-day save/load continuation tests.
- [ ] Verify RED.
- [ ] Extend resident/world persistence validation and decode.
- [ ] Verify GREEN including Plan 04 persistence/replay suites.
- [ ] Commit: `feat: persist resident schedules and goals`

### Task 8: Three-Day Six-Resident Soak

**Files:**
- Create: `tests/soak/test_daily_goals_schedules_soak.gd`
- Create: `docs/architecture/daily-goals-schedules.md`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Final Plan 05 verification.

- [ ] Build two identical six-resident worlds with different personality/job profiles.
- [ ] Run three simulated days with deterministic navigation feedback and a mid-day save/load split.
- [ ] Assert same-seed snapshot identity, 1–3 valid goals/resident/day, no duplicate daily generation, urgent needs override preference, and no invalid reservations.
- [ ] Run both GitHub workflows and inspect logs for hidden Godot errors/warnings.
- [ ] Document schedule/goal ownership, score bias rules, persistence and deferred UI/long-term goals.
- [ ] Commit: `docs: document daily goals and schedules architecture`

## Self-Review

- **Spec coverage:** schedule data/runtime, personal goals, deterministic generation, utility bias, rollover, persistence and multi-day soak all have owners.
- **Step scan:** each task has one RED → GREEN deliverable and a clear review boundary.
- **Type consistency:** resident state owns schedule/goal state; planner uses existing RNG/relationships/job data; persistence extends CharacterSnapshotCodec and SimulationWorld.
- **Review Focus:** overlap, midnight, duplicate rollover, urgent-need override and missing goal targets are assigned to Tasks 1, 5, 6 and 7.
- **Proportion:** implementation bodies are intentionally omitted; interfaces and test contracts fix the architectural decisions.
