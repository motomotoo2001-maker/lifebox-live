# LIFEBOX LIVE — Fate & Live Interaction Specification

## Goal

Connect viewer interaction to the autonomous simulation through a provider-neutral, deterministic LIVE event pipeline.

The simulation must continue normally when no provider is connected.

## Architecture boundary

Provider adapters live outside core simulation.

Provider adapter / MockLiveBridge → Normalized LiveEvent → LiveEventQueue + dedup/idempotency → LiveInteractionSystem → SimulationWorld state changes.

No TikTok SDK/API types may appear inside simulation-domain classes.

## LiveEvent

Required fields:
- event_id: stable non-empty string
- kind: StringName
- occurred_at_sim_seconds: float >= 0
- viewer_key: stable opaque viewer identifier, may be empty for anonymous/system events
- payload: Dictionary containing normalized provider-neutral values

Supported initial kinds:
- gift
- like_batch
- comment
- follow
- share

Unknown kinds are rejected by validation.

## Idempotency

Every accepted event_id is recorded in a bounded dedup ledger.

Rules:
- same event_id can mutate the world at most once;
- duplicate events are acknowledged as duplicates, not errors;
- ledger state persists across save/load;
- ledger capacity is bounded and deterministic;
- eviction is oldest-first.

## MockLiveBridge

The mock bridge is the reference adapter used in tests and offline development.

It:
- creates normalized events with deterministic sequence IDs;
- can enqueue gift, like batch, comment, follow and share events;
- does not depend on network access;
- can capture/restore its own deterministic sequence when needed by tests.

## Gift tier mapping

Normalized gift payload contains:
- gift_name: string
- gift_value: integer >= 0
- repeat_count: integer >= 1

Effective value = gift_value * repeat_count.

Initial deterministic tiers:
- micro: 0..9
- small: 10..49
- medium: 50..199
- large: 200..999
- legendary: 1000+

Thresholds are provider-independent.

## FateDefinition

A fate definition owns:
- stable id;
- eligible gift tiers;
- weight;
- cooldown_sim_seconds;
- rarity/category;
- target mode;
- preconditions;
- effect list.

Initial target modes:
- random_resident;
- lowest_need_resident;
- highest_relationship_pair;
- household.

Initial effect primitives:
- need_delta;
- money_delta;
- relationship_delta;
- chaos_delta.

No arbitrary script/code execution is allowed from event payloads.

## FateEngine

Input:
- gift tier;
- current world state;
- current simulation time;
- cooldown state;
- RNG.

Processing:
1. gather definitions that support the gift tier;
2. evaluate preconditions;
3. remove cooldown-blocked definitions;
4. choose deterministically by weighted RNG;
5. resolve deterministic target(s);
6. apply validated effect primitives;
7. record cooldown/trigger metadata;
8. emit a structured FateResult.

Same world state + same RNG state + same event stream must produce the same FateResult and final snapshot.

If no fate is eligible, gift processing succeeds as a no-op FateResult rather than crashing.

## Chaos Meter

Range: 0..100.

Initial behavior:
- like_batch payload uses count >= 1;
- likes add deterministic chaos points;
- explicit fate effects may add/remove chaos;
- clamped to 0..100;
- state persists.

Chaos is state/input for later Fate/Story weighting. This plan does not implement Story Director.

## Comments & voting

Comment payload:
- text: string

Parser recognizes !A and !B.

VoteSession owns:
- stable session_id;
- option A/B stable IDs and labels;
- viewer_key → selected option map;
- open/closed state.

Rules:
- viewer has at most one effective vote;
- later vote replaces earlier vote from same viewer;
- unknown commands do nothing;
- close() returns deterministic winner;
- ties use stable option-ID lexical tie-break;
- closed session ignores further votes;
- session persists.

## Persistence

World persistence must include LIVE domain state:
- queued events;
- dedup ledger;
- Chaos Meter;
- Fate cooldown state;
- active vote session.

Old Plan 05 snapshots without LIVE state remain readable using default empty LIVE state.

## Replay

Replay integration must be provider-neutral.

Recorded external inputs contain normalized LiveEvent data, not raw provider packets.

Replaying the same ordered LiveEvent sequence against the same snapshot must end in an exact same world snapshot.

## Safety / reliability

- malformed event payload never mutates state;
- one malformed event must not block later valid events;
- unknown kinds fail closed;
- duplicate event IDs do not reapply effects;
- queue processing is bounded per simulation step;
- no network access is required for tests;
- no LLM dependency.

## Definition of Done

- normalized event validation;
- deterministic MockLiveBridge;
- bounded idempotency ledger;
- gift tier mapping;
- context-aware deterministic FateEngine with cooldowns;
- likes → Chaos Meter;
- comment !A/!B voting;
- LIVE domain persistence;
- save/load mid-stream exact continuation;
- replay same stream exact snapshot identity;
- six-resident mixed LIVE-event soak;
- all Plan 01–05 tests remain green.