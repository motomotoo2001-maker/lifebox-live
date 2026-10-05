# LIFEBOX LIVE — Autonomous Household Architecture

## Scope

Plan 02 extends the deterministic simulation foundation into a six-resident household.

The simulation remains headless and authoritative for:

- resident identity and roster membership;
- needs and utility scoring;
- action selection;
- SmartObject reservations;
- logical movement intent;
- interaction timing and effects;
- movement timeout/retry policy.

The Godot 3D runtime is an adapter. It renders and moves actors, but it does not own utility scoring, RNG order, needs, or reservations.

## Core boundary

```text
SimulationWorld
  -> CharacterState
  -> UtilityAI
  -> ActionExecutor
  -> MovementState / MovementIntent
  -> logical destination

Presentation adapter
  <- movement intent
ResidentActor3D (CharacterBody3D)
  -> NavigationAgent3D
  -> movement_arrived / movement_failed
  -> SimulationWorld.report_arrival / report_movement_failure
```

This separation keeps headless simulation deterministic even if rendering, navigation, or a future streaming client runs at a different frame rate.

## Household roster

`HouseholdState` stores residents in deterministic insertion order and provides:

- `add_resident(character) -> bool`
- `remove_resident(character_id) -> bool`
- `get_resident(character_id) -> CharacterState`
- `residents() -> Array[CharacterState]`

Resident IDs must be non-empty and unique.

`SimulationWorld.add_character()` enforces the same invariant before allocating an executor.

## SmartObjects

A `SmartObject` owns:

- stable `object_id`;
- logical `interaction_point`;
- data-driven `InteractionDefinition` entries;
- a single-capacity reservation.

`SmartObjectRegistry` provides stable lookup and lifecycle control.

Important guarantees:

- duplicate object IDs are rejected;
- unregistering an object clears its reservation;
- freed/stale object references are removed rather than returned;
- a resident cannot steal another resident's reservation.

## Movement model

`MovementIntent` is pure simulation data:

- `target_object_id`
- `target_position`
- `arrival_radius`

Non-finite positions are invalid.

`MovementState` tracks:

- `idle`
- `moving`
- `arrived`
- `failed`
- elapsed simulated seconds;
- retry count;
- current intent.

It has no dependency on `NavigationAgent3D`.

## Move-before-interact flow

Actions with a SmartObject execute in two phases.

### 1. Moving

`ActionExecutor.start()`:

1. reserves the SmartObject;
2. creates a MovementIntent;
3. sets CharacterState movement to `moving`;
4. keeps the gameplay action active;
5. does **not** apply interaction effects.

### 2. Interacting

The presentation/runtime layer reports:

`SimulationWorld.report_arrival(character_id, target_object_id)`

The executor then enters the interaction phase and counts interaction duration.

Effects are applied only after the interaction completes.

Movement failure uses:

`SimulationWorld.report_movement_failure(character_id, target_object_id)`

and releases the reservation without applying interaction effects.

## 3D runtime adapter

`scenes/characters/resident_actor_3d.tscn` uses:

- root: `CharacterBody3D`
- child: `NavigationAgent3D`

`resident_actor_3d.gd` exposes:

- `bind_character(character_id)`
- `set_movement_target(target, arrival_radius)`
- `stop_movement()`
- `movement_arrived(character_id)`
- `movement_failed(character_id)`

Runtime rules:

- path queries occur from physics processing;
- navigation waits until the NavigationServer map has synchronized;
- `get_next_path_position()` supplies the next waypoint;
- avoidance-safe velocity is used when avoidance is enabled;
- movement uses Godot 4 `move_and_slide()` with no arguments.

The runtime adapter never changes utility scores or RNG state.

## Household blockout

`scenes/world/household_blockout.tscn` contains:

- `NavigationRegion3D` with authored navigation data;
- floor blockout geometry;
- six unique resident spawn markers;
- fridge destination;
- six bed destinations;
- shower destination;
- sofa destination.

This is functional navigation/blockout content, not final art.

## Six-resident contention

The headless contention contract verifies six hungry residents competing for one single-capacity fridge.

At any time:

- at most one resident may own the fridge;
- losing residents remain valid;
- they retry after the object is released;
- the first satisfied resident does not permanently monopolize the resource.

Multiple independent beds may be used concurrently.

## Stuck recovery

`StuckRecoveryPolicy` defaults to:

- movement timeout: 30 simulated seconds;
- maximum retries: 2.

Timeout behavior:

1. first timeout: increment retry count and reset elapsed movement time;
2. second timeout: repeat;
3. third timeout after retry budget is exhausted: fail movement;
4. ActionExecutor releases the target reservation;
5. resident returns to gameplay idle/action selection;
6. the resident can select another action later.

A stuck navigation adapter therefore cannot permanently lock a resident or SmartObject.

## Determinism and timing

`SimulationWorld` uses a fixed one-second internal simulation step.

External real delta is converted by `SimulationClock`, accumulated, and consumed in fixed steps.

This preserves deterministic state across coarse and fine render/update deltas.

Simulation time scale is finite and clamped to `0..20x`.

## Verification

Run from repository root:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

Plan 02 verification includes:

- identity and time-scale safety;
- HouseholdState roster behavior;
- SmartObject registry lifecycle;
- MovementIntent / MovementState;
- move-before-interact integration;
- six-resident contention;
- stuck recovery;
- ResidentActor3D scene/runtime contract;
- household blockout contract;
- Plan 01 regression suites;
- eight-hour six-resident accelerated soak.

## Eight-hour soak contract

The soak creates two independent but identical six-resident worlds.

Each world runs for exactly eight simulated hours with:

- fixed `20x` time scale;
- the same resident ordering;
- the same built-in RNG seed;
- one shared fridge;
- six beds;
- deterministic simulated navigation arrivals;
- deterministic simulated movement failures.

Assertions include:

- six unique resident IDs remain valid;
- all needs stay finite and inside `0..100`;
- no SmartObject has more than one active resident;
- active actions keep their target reserved;
- idle targets leave no stale reservation;
- movement cannot remain beyond the watchdog timeout;
- same-seed worlds produce identical sampled histories;
- both worlds complete exactly eight simulated hours.

## Plan 02 completion state

Verified on Godot 4.7.2:

- six residents: yes;
- unique identities: yes;
- single-capacity reservation safety: yes;
- move-before-interact: yes;
- navigation adapter contract: yes;
- household blockout: yes;
- stuck recovery: yes;
- deterministic eight-hour soak: yes;
- headless suite: 22 suites passing;
- hidden Godot SCRIPT ERROR / ERROR / WARNING lines: none in the final verification run.

## Deferred to the next layer

The following remain outside Plan 02:

- relationships and social graph;
- jobs and economy;
- episodic memory;
- social conversations;
- animation state-machine polish;
- persistence/save schema;
- Fate Engine and live-event transport;
- Story Director and Camera Director;
- final character/environment art.
