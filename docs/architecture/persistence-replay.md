# Persistence & Deterministic Replay

## Purpose

Plan 04 gives LIFEBOX LIVE a versioned, validated persistence boundary and a bounded deterministic replay layer. The simulation can be checkpointed, restored into an equivalent topology, continued without changing the deterministic outcome, and reconstructed from a short log of external inputs.

The persistence layer does not own scene construction. A destination `SimulationWorld` must already contain the same SmartObject topology before a world snapshot is restored.

## Ownership

- `SaveSchema`
  - owns the outer project/schema envelope;
  - current schema version: `1`.
- `SnapshotValidator`
  - validates envelope identity, version, and payload shape.
- `SaveMigrator`
  - migrates older supported envelopes to the current schema before use.
- `CharacterSnapshotCodec`
  - owns resident stable state.
- `SocialEconomySnapshotCodec`
  - owns relationship graph persistence and social/economy supporting state.
- `ActionSnapshotCodec`
  - owns active SmartObject action persistence.
- `SimulationWorld`
  - orchestrates the complete world snapshot and restore.
- `WorldSnapshotCodec`
  - exposes the world-level encode/restore boundary.
- `SaveService`
  - owns disk atomicity, backup recovery, and disk-format compatibility.
- `ReplayEvent`, `ReplayLog`, `ReplayPlayer`
  - own bounded external-input replay.

## World snapshot contents

`SimulationWorld.capture_persistence_state()` persists:

1. simulation clock;
2. fixed-step and economy-step accumulators;
3. residents in stable order;
4. active SmartObject actions;
5. relationship graph;
6. economy transaction/runtime state;
7. household-expense runtime;
8. active/completed social runtime;
9. deterministic RNG seed and internal state.

RNG values are represented as decimal strings in the logical world snapshot. This prevents 64-bit RNG values from being routed through JSON numeric conversion.

## Restore contract

Restore is validate-before-apply.

The destination world is expected to be a fresh or otherwise disposable simulation container with the required SmartObjects already registered. Validation first checks the entire snapshot, including resident IDs, relationships, runtime counters, RNG representation, active actions, social sessions, and references to topology.

The effective restore order is:

1. validate complete snapshot;
2. decode resident stable state;
3. build relationship state;
4. restore economy state;
5. restore household-expense state;
6. restore simulation clock;
7. clear active runtime/reservations in the destination;
8. install restored systems;
9. rebuild resident roster/executors in stable order;
10. restore active SmartObject actions;
11. restore social runtime;
12. restore fixed-step/economy accumulators;
13. restore RNG **seed first, state second**.

The seed/state order is required because assigning `RandomNumberGenerator.seed` changes the generator state.

## Topology requirements

Snapshots persist topology references, not scene ownership.

Before `WorldSnapshotCodec.restore()`:

- each referenced SmartObject must already exist in the destination;
- its `object_id` must match the saved reference;
- relevant InteractionDefinitions must be available;
- the destination topology must not contain conflicting active reservations.

This keeps core simulation persistence independent from the presentation scene tree.

## Disk format and atomic write

Logical save data remains a validated Dictionary/Array snapshot. New disk writes use a small JSON container:

```text
{
  "format": "lifebox_variant_base64_v1",
  "data": "<base64 encoded Godot Variant>"
}
```

The Base64 payload is produced with `Marshalls.variant_to_base64(..., false)` and decoded with `Marshalls.base64_to_variant(..., false)`.

Reasons:

- preserves Godot 64-bit integer values exactly;
- preserves 64-bit float Variant values exactly;
- preserves numeric Variant types;
- avoids deterministic drift caused by JSON number parsing;
- keeps object deserialization disabled.

The outer JSON contains only format metadata and Base64 text.

`SaveService` still reads the older plain-JSON envelope used earlier in Plan 04. Legacy JSON numeric values are normalized where safe before migration/validation.

### Atomic save algorithm

1. validate/migrate the candidate envelope;
2. encode the lossless disk record;
3. write `<path>.tmp`;
4. flush and close;
5. read/validate the temp candidate through the normal load path;
6. move existing main file to `<path>.bak`;
7. atomically rename temp to main;
8. if promotion fails, attempt to restore the previous backup;
9. never leave a successful operation with a stale temp file.

### Recovery

Load order is:

1. main file;
2. backup file if the main file is missing, malformed, invalid, or unsupported.

A corrupt main file therefore falls back to the last valid `.bak` checkpoint.

Malformed JSON is parsed with the instance `JSON.parse()` API so failure is handled as data rather than emitted as an engine parse error.

## Migration policy

All loaded envelopes go through `SaveMigrator.migrate_to_current()` before being exposed.

Current supported migration:

- v0 → v1: legacy `payload.characters` becomes `payload.residents`.

Rules:

- project ID must match LIFEBOX LIVE;
- unsupported future versions fail closed;
- malformed migration input fails closed;
- migrations operate on a duplicate rather than mutating caller-owned data;
- disk format and logical schema version are separate concerns.

## Replay contract

Replay stores only external reconstructive inputs. AI decisions are not recorded; they are regenerated from the restored world state and RNG.

Supported Plan 04 event kinds:

- `advance`
  - payload: `real_delta`;
- `movement_arrived`
  - payload: `character_id`, `target_object_id`;
- `movement_failed`
  - payload: `character_id`, `target_object_id`.

`ReplayLog`:

- assigns monotonic sequence numbers starting at 1;
- deep-copies payloads;
- rejects malformed/unknown events;
- rejects non-finite or negative advance deltas;
- has a hard `MAX_EVENTS = 4096` boundary;
- rejects overflow instead of silently discarding reconstructive inputs.

`ReplayPlayer` pre-validates the entire event list before restoring or advancing the destination world. Invalid sequence numbers, malformed payloads, unknown kinds, or overflow therefore cannot partially mutate the replay destination before execution begins.

For valid input:

1. restore the initial snapshot;
2. apply external events in exact sequence order;
3. allow simulation AI/social/utility decisions to regenerate from the restored RNG state.

## Determinism guarantees verified by Plan 04

The automated suite verifies:

- in-memory world snapshot → restore → re-encode exact equality;
- first RNG-driven decision after restore equals uninterrupted control;
- active SmartObject actions restore with valid reservations;
- active social sessions restore without duplicate participants;
- invalid snapshots do not partially mutate a destination;
- identical six-resident worlds are exact before the save/load split;
- after 4 simulated hours, restore into a fresh equivalent topology and continue both worlds for another 4 simulated hours;
- final full snapshots after 8 simulated hours are exactly equal;
- bounded external-input replay reaches the exact control snapshot;
- a corrupt primary disk save recovers the exact previous world snapshot from backup;
- disk save/load preserves exact 64-bit float/int Variant values;
- legacy plain-JSON envelopes remain readable;
- restored SmartObject/social reservations remain valid and non-duplicated.

Final Plan 04 regression baseline: **44 suites** on Godot **4.7.2**.

## Deferred state

The following are deliberately outside Plan 04 unless later systems make them simulation-authoritative:

- presentation-only camera state;
- HUD/UI animation state;
- renderer/transient visual effects;
- live-network socket state;
- provider-specific TikTok connection/session state;
- LLM request state;
- future Fate/Story Director queues not yet implemented.

When one of these becomes simulation-authoritative, its persistence ownership must be added explicitly rather than hidden inside generic dictionaries.
