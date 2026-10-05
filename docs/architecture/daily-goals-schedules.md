# Daily Goals & Schedules

## Purpose

Plan 05 gives LIFEBOX LIVE residents a deterministic daily rhythm and short-term personal objectives without turning them into scripted NPCs.

Needs remain authoritative. Schedules and goals only bias autonomous Utility AI decisions.

## Ownership

- `ScheduleBlock`
  - one time window inside a repeating 24-hour day;
  - owns semantic action tags such as `sleep`, `eat`, `work`, `relax`, `social`.
- `ScheduleDefinition`
  - owns ordered schedule blocks;
  - validates hours, duration, duplicate IDs and overlaps;
  - resolves the active block at a local hour, including midnight-crossing blocks.
- `DailyScheduleState`
  - resident-owned schedule definition;
  - current simulated day index;
  - active block ID.
- `DailyScheduleSystem`
  - derives schedule day/block directly from absolute simulation seconds.
- `GoalDefinition`
  - immutable goal intent: category, priority, preferred action tags and optional resident target.
- `GoalState`
  - runtime progress and status: active / completed / failed.
- `GoalSet`
  - resident-owned current-day goal set;
  - maximum three active goals;
  - day rollover boundary.
- `DailyGoalPlanner`
  - creates 1–3 deterministic goals from personality, job and relationships.
- `DailyPlanningSystem`
  - updates schedules and rolls daily goals once per day.
- `DecisionBiasSystem`
  - modifies candidate scores from active schedule/goal tags;
  - owns critical hunger/energy protection.
- `CharacterSnapshotCodec`
  - persists schedule and goal state.
- `SimulationWorld`
  - runs planning in the fixed-step loop and validates restored goal resident targets.

## Deterministic daily planning

Daily goals do not consume the simulation's main RNG state.

For each resident/day, `DailyPlanningSystem` derives a local seed from:

```text
world RNG seed + resident ID + simulated day index
```

That local RNG is passed to `DailyGoalPlanner`.

Consequences:

- adding daily planning does not shift old Utility AI tie-break decisions;
- same world seed + same resident ID + same day produces the same goals;
- save/load does not require a separate planning RNG stream;
- replay remains reconstructive from existing world state.

## Personality-driven goals

The planner always has a wellbeing/fun baseline and conditionally adds social/work candidates.

Dominant traits at or above `0.9` guarantee their valid goal category:

- sociability → social goal, only when an outgoing relationship target exists;
- ambition + assigned job → work goal;
- impulsiveness → fun goal.

Remaining slots are chosen by deterministic weighted sampling without replacement.

Social target selection is deterministic: highest outgoing affinity wins, with resident ID as the tie-break.

## Schedule semantics

Schedules repeat every 24 simulated hours.

A block contains:

- stable ID;
- semantic kind;
- start hour;
- duration;
- preferred action tags.

Blocks may cross midnight. Overlaps are invalid.

Schedules do not force an action. If the current block prefers `work`, it only raises the score of interactions tagged `work`.

## Utility score integration

`InteractionDefinition.action_tags` is the semantic bridge between SmartObject interactions, schedules and goals.

For a normal resident state:

1. base score is produced from need deficits/effects;
2. spending policy adjusts the score;
3. schedule match adds a bounded bonus;
4. each matching active goal adds a priority-scaled bonus;
5. Utility AI chooses from final candidate scores.

Interactions without action tags preserve Plan 01–04 behavior.

## Critical-need safety floor

If hunger or energy is at or below `20`:

- an interaction that positively restores any currently critical need is strongly boosted;
- non-critical candidates are suppressed;
- schedule and goal bonuses do not override the critical need.

This keeps planning as preference rather than hard scripting.

## Daily rollover

`DailyPlanningSystem` runs inside the fixed simulation step.

On a new day:

1. schedule state moves to the new day;
2. unfinished previous-day goals are marked failed;
3. previous daily goal entries are cleared from the active daily set;
4. a deterministic local planning RNG is derived;
5. 1–3 new goals are generated and installed.

Repeated calls within the same day are idempotent.

Planning itself does not pay wages, spend money or advance job work time. Economy remains owned by existing economy/job systems.

## Persistence

New resident snapshots write optional top-level sections:

- `schedule`
- `goals`

They persist:

### Schedule
- day index;
- active block ID;
- definition blocks and semantic tags.

### Goals
- day index;
- goal definition;
- category;
- priority;
- preferred tags;
- optional target resident ID;
- progress;
- status.

The fields are optional when reading so Plan 04 resident snapshots remain backward-compatible.

At world validation time, non-empty goal target resident IDs must exist in the restored resident roster and cannot point to self.

## Three-day soak contract

Plan 05's final soak uses six residents with:

- different personality profiles;
- different job start times;
- valid 24-hour schedules;
- tagged eat/sleep/relax/spend/work interactions;
- deterministic relationship targets.

The soak:

1. runs two identical worlds for 1.5 simulated days;
2. snapshots one world;
3. restores it into fresh equivalent SmartObject topology;
4. continues control and restored worlds until just before the end of day 3;
5. requires exact final full-snapshot equality.

It also checks:

- 1–3 active goals per resident/day;
- stable same-day goal signatures;
- all three simulated planning days observed;
- dominant personality goal categories;
- active schedule block correctness;
- schedule diversity from different job contexts;
- critical hunger safety;
- SmartObject/social reservation integrity.

## Deferred

Plan 05 deliberately does not add:

- goal HUD/UI;
- long-term weekly/monthly aspirations;
- LLM-generated goals;
- physical workplace commuting;
- Story Director/Fate Engine goal injection;
- dialogue generated from goals.

Those systems should consume the stable schedule/goal contracts rather than replace them.
