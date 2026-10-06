# Fate & Live Interaction Implementation Plan

> Native execution. Implement task-by-task with RED → GREEN tests.

**Goal:** Add a provider-neutral deterministic LIVE input layer: gifts trigger Fate events, likes drive Chaos Meter, comments drive voting, duplicate network events never apply twice, and save/load/replay remain exact.

**Architecture:** `LiveInteractionSystem` owns queue, dedup ledger, chaos, votes, Fate cooldowns and a dedicated Fate RNG stream. `SimulationWorld` calls it at a bounded point in the fixed-step loop. Provider adapters only create normalized `LiveEvent` values.

**Spec:** `docs/superpowers/specs/2026-10-06-fate-live-interaction-spec.md`

## Global constraints

- Godot 4.7.2 / GDScript.
- No TikTok/provider SDK types in simulation domain.
- Every accepted event has stable `event_id`.
- Duplicate event ID mutates state at most once.
- Dedicated LIVE/Fate RNG; do not perturb core UtilityAI RNG.
- At most 8 queued LIVE events processed per fixed simulation step.
- Malformed event fails closed and does not block later events.
- Plan 01–05 regression stays green.
- Old Plan 05 snapshots without LIVE state remain readable.

### Task 1 — Normalized LiveEvent contract

Files:
- Create `scripts/integrations/live/live_event.gd`
- Create `tests/unit/test_live_event.gd`
- Modify `tests/test_runner.gd`

Contract:
- kinds: gift, like_batch, comment, follow, share;
- `event_id`, `kind`, `occurred_at_sim_seconds`, `viewer_key`, `payload`;
- kind-specific payload validation;
- JSON/Variant persistence-safe encode/decode.

RED/GREEN:
- reject empty/duplicate-unsafe identity, negative/non-finite time, unknown kind, malformed gift/like/comment payload;
- accept valid normalized events and exact encode/decode.

### Task 2 — Bounded queue + idempotency ledger

Files:
- Create `scripts/integrations/live/live_event_queue.gd`
- Create `scripts/integrations/live/event_id_ledger.gd`
- Create `tests/unit/test_live_event_queue.gd`
- Modify runner.

Contract:
- FIFO queue;
- max pending capacity;
- bounded processed-ID ledger with oldest-first eviction;
- duplicate pending or processed event IDs rejected as duplicate;
- malformed event does not enter queue.

### Task 3 — Deterministic MockLiveBridge

Files:
- Create `scripts/integrations/live/mock_live_bridge.gd`
- Create `tests/unit/test_mock_live_bridge.gd`
- Modify runner.

Contract:
- deterministic sequence IDs;
- helpers for gift, like batch, comment, follow, share;
- bridge emits normalized LiveEvent only;
- capture/restore sequence.

### Task 4 — Gift tiers, Chaos Meter and comment commands

Files:
- Create `scripts/simulation/fate/gift_tier_mapper.gd`
- Create `scripts/simulation/fate/chaos_meter.gd`
- Create `scripts/integrations/live/comment_command_parser.gd`
- Create unit tests for each.

Contract:
- effective gift value = value * repeat count;
- tiers micro/small/medium/large/legendary;
- chaos range 0..100, likes add deterministic amount;
- parser recognizes trimmed case-insensitive `!A` / `!B` only.

### Task 5 — VoteSession

Files:
- Create `scripts/simulation/fate/vote_session.gd`
- Create `tests/unit/test_vote_session.gd`
- Modify runner.

Contract:
- exactly A/B stable option IDs;
- one effective vote per viewer;
- later vote replaces previous vote;
- closed session ignores votes;
- deterministic lexical tie-break;
- exact persistence round-trip.

### Task 6 — FateDefinition + FateEngine

Files:
- Create `scripts/simulation/fate/fate_definition.gd`
- Create `scripts/simulation/fate/fate_result.gd`
- Create `scripts/simulation/fate/fate_engine.gd`
- Create `tests/integration/test_fate_engine.gd`
- Modify runner.

Contract:
- tier eligibility, weight, cooldown, rarity/category, target mode, preconditions, effects;
- target modes: random resident, lowest need resident, highest relationship pair, household;
- effect primitives: need delta, money delta, relationship delta, chaos delta;
- weighted deterministic selection using dedicated Fate RNG;
- no eligible fate returns no-op result;
- cooldown enforced by simulation time;
- malformed effect never partially applies.

### Task 7 — LiveInteractionSystem + SimulationWorld integration

Files:
- Create `scripts/integrations/live/live_interaction_system.gd`
- Modify `scripts/simulation/simulation_world.gd`
- Create `tests/integration/test_live_interaction_pipeline.gd`
- Modify runner.

Contract:
- owns queue, processed ledger, chaos, FateEngine, vote session and dedicated Fate RNG;
- max 8 events processed per fixed step;
- gift → tier → fate;
- likes → chaos;
- comment → active vote;
- follow/share accepted as normalized no-op hooks for later Story Director;
- duplicate IDs never reapply;
- bad event never blocks next valid event.

### Task 8 — Persistence + replay integration

Files:
- Extend world persistence with optional `live_interaction` section;
- Extend/bridge replay normalized external-input events;
- Create `tests/integration/test_live_interaction_snapshot_restore.gd`
- Create `tests/integration/test_live_event_replay.gd`
- Modify runner.

Contract:
- persist queue, ledger, chaos, cooldowns, vote, Fate RNG;
- old Plan 05 snapshot without LIVE state restores defaults;
- save/load mid-queue exact continuation;
- same snapshot + same ordered LiveEvent stream → exact final snapshot.

### Task 9 — Mixed LIVE event soak + docs

Files:
- Create `tests/soak/test_live_interaction_soak.gd`
- Create `docs/architecture/fate-live-interaction.md`
- Modify runner.

Soak:
- six residents;
- gifts across all tiers;
- duplicate gifts;
- large like batches;
- comment vote changes from same viewers;
- malformed events interleaved with valid events;
- save/load split;
- same-stream control/restored worlds end snapshot-identical;
- dedup ledger remains bounded;
- no invalid need/money/relationship/chaos values;
- all Plan 01–05 suites remain green.

## Completion gate

- both GitHub workflows success;
- `TESTS PASS` count includes all new suites;
- no hidden `SCRIPT ERROR / ERROR / WARNING`;
- Notion and Drive checkpoints updated before starting Plan 07.