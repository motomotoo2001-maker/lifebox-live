# LIFEBOX LIVE — Simulation Foundation

## Purpose

Plan 01 establishes a deterministic, headless simulation core for LIFEBOX LIVE.
It intentionally contains no rendering, TikTok transport, LLM dependency, navigation,
relationships, persistence, or production content.

## Runtime contracts

### SimulationClock

`SimulationClock` owns simulation time.

- `set_time_scale(value: float)` clamps to `0.0..20.0`.
- `advance(real_delta: float) -> float` converts real time to simulation time.
- `get_simulation_seconds() -> float` returns accumulated simulation seconds.
- `tick(sim_delta)` is emitted only for positive simulation deltas.
- Simulation behavior does not depend on render FPS.

### Need model

Every resident owns a `NeedProfile` containing:

- hunger
- energy
- hygiene
- comfort
- social
- mood

Each `NeedState.value` is clamped to `0..100`.

- `100` means fully satisfied.
- `0` means critical.
- NaN deltas are ignored.
- Need decay is expressed per simulated hour.

### Character state

`CharacterState` currently owns:

- stable `id`
- `display_name`
- `NeedProfile`
- eight normalized personality traits
- money
- current action id

The default action is `idle`.

### SmartObject

A `SmartObject` exposes data-driven `InteractionDefinition` resources and a
single-user reservation contract.

- the current owner may reuse its reservation;
- another resident cannot steal it;
- completion/cancel releases it;
- destruction clears reservation state.

### Utility AI

`UtilityAI.choose()` receives pre-scored `ActionCandidate` values.

- invalid candidates are ignored;
- unavailable SmartObjects are ignored;
- highest score wins;
- equal scores use the supplied RNG;
- same RNG seed produces the same tie result;
- no valid candidate returns `idle`.

### Action execution

`ActionExecutor` owns one active interaction for one resident.

- reserves the target SmartObject;
- tracks remaining simulated duration;
- applies configured need effects on completion;
- releases the reservation;
- returns the resident to `idle`.

### SimulationWorld

`SimulationWorld.step(real_delta)` is the Plan 01 orchestration boundary.

For every resident it:

1. advances simulation time;
2. decays needs;
3. advances an active action, or
4. builds interaction candidates;
5. scores positive need restoration as need deficit × effect strength;
6. lets UtilityAI select an action;
7. starts the selected interaction.

The Plan 01 fixture supports `eat`, `sleep`, and `idle`.

## Headless verification

From repository root with Godot 4.7.2 on PATH:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

The same suite is executed in GitHub Actions.

The suite includes:

- boot/version test;
- SimulationClock unit tests;
- EventBus unit tests;
- NeedState/NeedProfile unit tests;
- CharacterState/PersonalityState unit tests;
- NeedSystem unit tests;
- SmartObject reservation tests;
- UtilityAI deterministic selection tests;
- single-resident integration test;
- accelerated deterministic soak test.

## Soak contract

The foundation soak creates two identical worlds and advances both with:

- fixed `20x` time scale;
- identical initial state;
- identical built-in RNG seed;
- 96 simulation steps.

It asserts:

- all needs remain in `0..100`;
- no invalid action id appears;
- reservation ownership matches the active action;
- no stale reservation remains while idle;
- the two worlds produce identical action histories.

## Scope boundary

Plan 02 may add navigation, six simultaneous residents, richer SmartObjects,
relationships, jobs/economy, animation hooks and stuck-agent recovery. Those systems
must depend on these contracts rather than bypassing them.
